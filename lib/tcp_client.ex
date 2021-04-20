defmodule TcpClient do
  @moduledoc """
  Docummentation for TcpClient
  """
  # ----------------------------------------------------------------------------------------------
  use GenServer
  require Logger

  # ----------------------------------------------------------------------------------------------
  defstruct [
    :name,
    :addr,
    :socket,
    :tls_socket,
    credits: []
  ]

  # ----------------------------------------------------------------------------------------------
  # API
  # ----------------------------------------------------------------------------------------------
  @doc """
    Sends tcp or ssl message
  """
  def send(name, data), do: GenServer.cast(name, {:send, data})

  @doc """
    Returns information about current state
  """
  def get_status(name), do: GenServer.call(name, :info)

  # ----------------------------------------------------------------------------------------------

  def start(name, saddr), do: start(name, saddr, Util.default_credits())

  def start(name, saddr, credits) do
    GenServer.start(__MODULE__, {name, saddr, credits}, name: name)
  end

  def start_link(name, saddr), do: start_link(name, saddr, Util.default_credits())

  def start_link(name, saddr, credits) do
    GenServer.start_link(__MODULE__, {name, saddr, credits}, name: name)
  end

  @impl true
  def init({name, {addr, port}, credits}) when is_binary(addr) do
    init({name, {to_charlist(addr), port}, credits})
  end

  @impl true
  def init({name, {addr, port}, credits}) do
    Process.flag(:trap_exit, true)

    Logger.info("Started #{__MODULE__}")
    {:ok, ip} = :inet.parse_ipv4strict_address(addr)

    state = %__MODULE__{
      name: name,
      addr: {ip, port},
      credits: credits
    }

    Kernel.send(self(), :connect)
    Logger.info(state: state)
    {:ok, state}
  end

  # ----------------------------------------------------------------------------------------------
  # callbacks
  # ----------------------------------------------------------------------------------------------

  @impl true
  def handle_cast(msg = {:send, data}, state) when state.socket != nil and state.credits == [] do
    Logger.debug(msg: msg)

    case :gen_tcp.send(state.socket, data) do
      :ok -> :ok
      reason -> Logger.error(not_sent: reason)
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast(msg = {:send, data}, state) when state.tls_socket != nil do
    Logger.info(msg: msg)

    case :ssl.send(state.tls_socket, data) do
      :ok -> :ok
      reason -> Logger.error(not_sent: reason)
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:send, _data}, state) do
    Logger.error("socket is not opened")
    {:noreply, state}
  end

  @impl true
  def handle_cast(msg, state) do
    Logger.error(uknown: msg)
    {:noreply, state}
  end

  # ----------------------------------------------------------------------------------------------

  @impl true
  def handle_call(:info, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(msg, _from, state) do
    Logger.error(uknown: msg)
    {:reply, nil, state}
  end

  # ----------------------------------------------------------------------------------------------

  @impl true
  def handle_info(msg = :connect, state) do
    Logger.info(msg: msg)
    self = self()
    spawn(fn -> do_connect(self, state.addr) end)
    {:noreply, state}
  end

  @impl true
  def handle_info(msg = {:connect, socket}, state) do
    Logger.info(msg: msg)
    if state.credits != [], do: Kernel.send(self(), :handshake)
    {:noreply, %{state | socket: socket}}
  end

  @impl true
  def handle_info(msg = :handshake, state) do
    Logger.info(msg: msg)
    self = self()
    pid = spawn(fn -> do_handshake(self, state.socket, state.credits) end)
    :gen_tcp.controlling_process(state.socket, pid)
    Kernel.send(pid, {:go, self})
    {:noreply, state}
  end

  @impl true
  def handle_info(msg = {:handshake, tls_socket}, state) do
    Logger.info(msg: msg)
    {:noreply, %{state | tls_socket: tls_socket}}
  end

  @impl true
  def handle_info(msg = {:report, _msg}, state) do
    Logger.info(msg: msg)
    {:noreply, state}
  end

  @impl true
  def handle_info(msg = {:tcp_closed, _msg}, state) do
    Logger.info(msg: msg)
    Kernel.send(self(), {:restart, msg})
    {:noreply, state}
  end

  @impl true
  def handle_info(msg = {:restart, _msg}, state) do
    Logger.info(msg: msg)

    spawn(fn ->
      Xtlsmlpp.Supervisor.terminate_child(state.name)
      Xtlsmlpp.Supervisor.restart_child(state.name)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(msg = {:stop, _msg}, state) do
    Logger.info(msg: msg)
    spawn(fn -> Xtlsmlpp.Supervisor.terminate_child(state.name) end)
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.error(uknown: msg)
    {:noreply, state}
  end

  # ----------------------------------------------------------------------------------------------

  @impl true
  def terminate(msg, state) do
    Logger.info(msg: msg)
    close_socket(:ssl, state.tls_socket)
    close_socket(:tcp, state.socket)
  end

  # ----------------------------------------------------------------------------------------------
  # helpers
  # ----------------------------------------------------------------------------------------------

  defp close_socket(_, nil), do: :ok
  defp close_socket(:tcp, socket), do: :gen_tcp.close(socket)
  defp close_socket(:ssl, socket), do: :ssl.close(socket)

  defp do_connect(parent, {ip, port}) do
    case :gen_tcp.connect(ip, port, []) do
      {:ok, socket} ->
        :gen_tcp.controlling_process(socket, parent)
        Kernel.send(parent, {:connect, socket})

      {error, reason} ->
        Kernel.send(parent, {:report, {error, reason}})
    end
  end

  defp do_handshake(parent, socket, credits) do
    receive do
      {:go, pid} when pid == parent ->
        case :ssl.connect(socket, credits) do
          {:ok, tls_socket} ->
            :gen_tcp.controlling_process(socket, parent)
            :ssl.controlling_process(tls_socket, parent)
            Kernel.send(parent, {:handshake, tls_socket})

          error ->
            Kernel.send(parent, {:report, error})
        end
    end
  end
end

# ----------------------------------------------------------------------------------------------
# examples
# ----------------------------------------------------------------------------------------------
# credits = [certfile: "/home/anatoly/prj/elixir/xtlsmlpp/priv/cert.pem", keyfile: "/home/anatoly/prj/elixir/xtlsmlpp/priv/key.pem"]
# credits = []
# TcpClient.start(:cc, {"127.0.0.1", 9999}, credits)
# TcpClient.send(:cc, "qqqqqq")
# TcpClient.get_status(:cc)
# TcpClient.send(:"TcpClient_127.0.0.1:9999", "qwerty!")
# ----------------------------------------------------------------------------------------------
