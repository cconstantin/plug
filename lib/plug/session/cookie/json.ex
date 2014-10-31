defmodule Plug.Session.COOKIE.JSON do
  @moduledoc """
  Serializes cookies as JSON.

  It requires a :json_encoder to be provided.

  ## Examples
      # Use Poison to encode/decode JSON
      plug Plug.Session, store: :cookie,
                         key: "_my_app_session",
                         encryption_salt: "cookie store encryption salt",
                         signing_salt: "cookie store signing salt",
                         serializer: :json,
                         json_encoder: Poison
  """

  @behaviour Plug.Session.COOKIE.Serializer

  def init(opts) do
    encoder = Keyword.get(opts, :json_encoder) ||
                raise ArgumentError, "JSON cookie serializer expects :json_encoder as option"
    %{encoder: encoder}
  end

  def encode(term, opts) do
    case opts.encoder.encode(term) do
      {:ok, term} -> {:ok, term}
      {:error, _} -> :error
      :error -> :error
      term -> {:ok, term}
    end
  end

  def decode(binary, opts) do
    case opts.encoder.decode(binary) do
      {:ok, term} -> {:ok, term}
      {:error, _} -> :error
      :error -> :error
      term -> {:ok, term}
    end
  end
end
