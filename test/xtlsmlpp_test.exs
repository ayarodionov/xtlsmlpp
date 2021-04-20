defmodule XtlsmlppTest do
  use ExUnit.Case
  doctest Xtlsmlpp

  test "greets the world" do
    assert Xtlsmlpp.hello() == :world
  end

  test "MLPP encoding/decoding" do
    msg = "qwerty"
    assert msg == MLPP.decode(MLPP.encode(msg))
  end
end
