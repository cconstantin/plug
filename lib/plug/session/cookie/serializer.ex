defmodule Plug.Session.COOKIE.Serializer do
  @moduledoc """
  Specification for cookie serializers.
  """
  use Behaviour

  @moduledoc """
  Initializes the serializer.

  The options returned from this function will be given
  to `encode/2`, and `decode/2`.
  """
  defcallback init(Plug.opts) :: Plug.opts

  @moduledoc """
  Serializes the cookie
  """
  defcallback encode(term, Plug.opts) :: {:ok, binary} | :error

  @moduledoc """
  Deserializes the cookie
  """
  defcallback decode(binary, Plug.opts) :: {:ok, term} | :error
end
