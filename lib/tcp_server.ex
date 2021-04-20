defmodule TcpServer do
  @moduledoc """
  Docummentation for TcpServer
  """
  # ----------------------------------------------------------------------------------------------
  use GenServer
  require Logger

  # ----------------------------------------------------------------------------------------------
  defstruct [
    :name,
    :addr,
    :socket,
    :lsocket,
    :tls_socket,
    credits: []
  ]

  # ----------------------------------------------------------------------------------------------
  # API
  # ----------------------------------------------------------------------------------------------
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
    {:ok, lsocket} = :gen_tcp.listen(port, [{:reuseaddr, true}, {:ip, ip}])

    state = %__MODULE__{
      name: name,
      addr: {ip, port},
      lsocket: lsocket,
      credits: credits
    }

    Kernel.send(self(), :accept)
    Logger.info(state: state)
    {:ok, state}
  end

  # ----------------------------------------------------------------------------------------------
  # callbacks
  # ----------------------------------------------------------------------------------------------

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
  def handle_info(msg = {:ssl, _, _}, state) do
    Logger.info(msg: msg)
    {:noreply, state}
  end

  @impl true
  def handle_info(msg = {:tcp, _, _}, state) do
    Logger.info(msg: msg)
    {:noreply, state}
  end

  @impl true
  def handle_info(msg = :accept, state) do
    Logger.info(msg: msg)
    self = self()
    spawn(fn -> do_accept(self, state.lsocket) end)
    {:noreply, state}
  end

  @impl true
  def handle_info(msg = {:accept, socket}, state) do
    Logger.info(msg: msg)

    case state.credits do
      [] -> :inet.setopts(socket, [{:active, true}, :binary])
      _ -> Kernel.send(self(), :handshake)
    end

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
    :inet.setopts(state.socket, [{:active, true}])
    :ssl.setopts(tls_socket, [{:active, true}])
    {:noreply, %{state | tls_socket: tls_socket}}
  end

  @impl true
  def handle_info(msg = {:tcp_closed, _msg}, state) do
    Logger.info(msg: msg)
    Kernel.send(self(), {:restart, msg})
    {:noreply, state}
  end

  @impl true
  def handle_info(msg = {:ssl_closed, _msg}, state) do
    Logger.info(msg: msg)
    Kernel.send(self(), {:restart, msg})
    {:noreply, state}
  end

  @impl true
  def handle_info(msg = {:report, _msg}, state) do
    Logger.info(msg: msg)
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
    close_socket(:tcp, state.lsocket)
  end

  # ----------------------------------------------------------------------------------------------
  # helpers
  # ----------------------------------------------------------------------------------------------

  defp close_socket(_, nil), do: :ok
  defp close_socket(:tcp, socket), do: :gen_tcp.close(socket)
  defp close_socket(:ssl, socket), do: :ssl.close(socket)

  defp do_accept(parent, lsocket) do
    case :gen_tcp.accept(lsocket) do
      {:ok, socket} ->
        :gen_tcp.controlling_process(socket, parent)
        Kernel.send(parent, {:accept, socket})

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
# credits = [certfile: '/home/anatoly/prj/elixir/xtlsmlpp/priv/cert.pem', keyfile: '/home/anatoly/prj/elixir/xtlsmlpp/priv/key.pem']
# credits = []
# TcpServer.start(:ss, {'127.0.0.1', 9999}, credits)
# TcpServer.get_status(:ss)
# ----------------------------------------------------------------------------------------------
