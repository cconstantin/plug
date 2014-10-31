defmodule Plug.Session.COOKIE.ETF do
  @moduledoc """
  Serializes cookies as Erlang external term format.
  """

  @behaviour Plug.Session.COOKIE.Serializer

  def init(_opts), do: nil

  def encode(term, _opts), do:
    {:ok, :erlang.term_to_binary(term)}

  def decode(binary, _opts), do:
    {:ok, :erlang.binary_to_term(binary)}
end
