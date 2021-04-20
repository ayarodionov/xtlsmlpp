defmodule Xtlsmlpp.Application do
  @moduledoc """
  Documentation for `Xtlsmlpp`.
  """

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications

  use Application
  require Logger

  @doc """
    Starts Unid module
  """
  def start(_type, _args) do
    Logger.info("Started #{__MODULE__}")
    Xtlsmlpp.Supervisor.start_link()
  end
end
