defmodule Plug.Crypto.MessageVerifierTest do
  use ExUnit.Case, async: true

  alias Plug.Crypto.MessageVerifier, as: MV

  test "generates a signed message" do
    [content, encoded] = String.split MV.sign("hello world", "secret"), "--"
    assert content |> Base.decode64 == {:ok, "hello world"}
    assert byte_size(encoded) == 40
  end

  test "verifies a signed message" do
    signed = MV.sign("hello world", "secret")
    assert MV.verify(signed, "secret") == {:ok, "hello world"}
  end

  test "does not verify a signed message if secret changed" do
    signed = MV.sign("hello world", "secret")
    assert MV.verify(signed, "secreto") == :error
  end

  test "does not verify a tampered message" do
    [_, encoded] = String.split MV.sign("hello world", "secret"), "--"
    content = Base.encode64("another world")
    assert MV.verify(content <> "--" <> encoded, "secret") == :error
  end
end
