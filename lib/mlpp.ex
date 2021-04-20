# -----------------------------------------------------------------------------------------------
defmodule MLPP do
  @moduledoc """
   MLLP coder and decoder.H 
   See <a href="https://www.hl7.org/documentcenter/public/wg/inm/mllp_transport_specification.PDF">mlpp specification</a>
  """

  @sb 0x0B
  @eb 0x1C
  @cr 0x0D

  # -----------------------------------------------------------------------------------------------
  @doc """
  Encodes to MLLP format
  """
  @spec encode(binary()) :: binary()
  def encode(msg) do
    <<@sb::8, msg::binary, @eb::8, @cr::8>>
  end

  # -----------------------------------------------------------------------------------------------
  @doc """
  Decodes from MLLP format
  """
  @spec decode(binary()) :: binary()
  def decode(<<@sb::8, m::binary>>) do
    l = byte_size(m) - 2
    <<msg::binary-size(l), @eb::8, @cr::8>> = m
    msg
  end
end

# -----------------------------------------------------------------------------------------------
# msg = "qwerty"
# msg == MLPP.decode(MLPP.encode(msg))
