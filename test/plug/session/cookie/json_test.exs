defmodule Plug.Session.COOKIE.JSONTest do
  use ExUnit.Case
  alias Plug.Session.COOKIE.JSON

  defmodule Encoder do
    def encode(%{foo: :bar}), do: {:ok, "encoded term"}
    def encode(_), do: :error
    def decode("encoded term"), do: {:ok, %{foo: :bar}}
    def decode(_), do: :error
  end

  test "requires json_encoder option to be defined" do
    assert_raise ArgumentError, ~r/expects :json_encoder as option/, fn ->
      JSON.init([])
    end
  end

  test "uses json_encoder to encode" do
    opts = JSON.init json_encoder: Encoder

    assert {:ok, "encoded term"} == JSON.encode(%{foo: :bar}, opts)
  end

  test "returns :error on encoding error" do
    opts = JSON.init json_encoder: Encoder

    assert :error == JSON.encode("invalid term", opts)
  end

  test "uses json_encoder to decode" do
    opts = JSON.init json_encoder: Encoder

    assert {:ok, %{foo: :bar}} == JSON.decode("encoded term", opts)
  end

  test "returns :error on decoding error" do
    opts = JSON.init json_encoder: Encoder

    assert :error == JSON.decode("invalid binary", opts)
  end

  test "encode and decode term" do
    opts = JSON.init json_encoder: Encoder

    {:ok, serialized} = JSON.encode(%{foo: :bar}, opts)
    assert {:ok, %{foo: :bar}} == JSON.decode(serialized, opts)
  end
end
