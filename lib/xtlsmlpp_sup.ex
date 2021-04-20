defmodule Xtlsmlpp.Supervisor do
  use Supervisor
  require Logger

  # ----------------------------------------------------------------------------------------------
  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
    Logger.info("Started #{__MODULE__}")

    servers = for x <- Application.get_env(:xtlsmlpp, :TcpServer), do: mk_child(:TcpServer, x)
    clients = for x <- Application.get_env(:xtlsmlpp, :TcpClient), do: mk_child(:TcpClient, x)
    children = servers ++ clients
    Logger.info(children: children)
    Supervisor.init(children, strategy: :one_for_one)
  end

  # ----------------------------------------------------------------------------------------------

  def count_children(), do: Supervisor.count_children(__MODULE__)

  def delete_child(child_id), do: Supervisor.delete_child(__MODULE__, child_id)

  def restart_child(child_id), do: Supervisor.restart_child(__MODULE__, child_id)

  def start_child(child_spec_or_args), do: Supervisor.start_child(__MODULE__, child_spec_or_args)

  def terminate_child(child_id), do: Supervisor.terminate_child(__MODULE__, child_id)

  def stop(reason), do: Supervisor.stop(__MODULE__, reason)

  def which_children(), do: Supervisor.which_children(__MODULE__)

  # ----------------------------------------------------------------------------------------------
  # helpers
  # ----------------------------------------------------------------------------------------------

  defp mk_name(type, {ip, port}) do
    String.to_atom(Atom.to_string(type) <> "_" <> ip <> ":" <> Integer.to_string(port))
  end

  defp mk_child(mod, {{ip, port}, :default}), do: mk_child(mod, {{ip, port}, []})

  defp mk_child(mod, {{ip, port}, credits}) do
    name = mk_name(mod, {ip, port})
    module = get_module(mod)

    %{
      id: name,
      start: {module, :start_link, [name, {ip, port}, credits]},
      type: :worker,
      restart: :permanent,
      modules: [module]
    }
  end

  defp get_module(:TcpClient), do: TcpClient
  defp get_module(:TcpServer), do: TcpServer

  # ----------------------------------------------------------------------------------------------
end
# ----------------------------------------------------------------------------------------------
# examples
# ----------------------------------------------------------------------------------------------
# Xtlsmlpp.Supervisor.which_children()
# Xtlsmlpp.Supervisor.count_children()
# Xtlsmlpp.Supervisor.terminate_child(:"TcpServer_127.0.0.1:9999")
# Xtlsmlpp.Supervisor.restart_child(:"TcpServer_127.0.0.1:9999")
# send(:"TcpServer_127.0.0.1:9999", {:restart, :manual})
# ----------------------------------------------------------------------------------------------
