defmodule Plug.Session.COOKIE.ETFTest do
  use ExUnit.Case
  alias Plug.Session.COOKIE.ETF

  test "encode and decode term" do
    {:ok, serialized} = ETF.encode(%{foo: :bar}, nil)
    assert {:ok, %{foo: :bar}} == ETF.decode(serialized, nil)
  end
end
