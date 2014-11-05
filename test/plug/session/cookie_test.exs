defmodule Plug.Session.CookieTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Plug.Session.COOKIE, as: CookieStore

  @default_opts [
    store: :cookie,
    key: "foobar",
    encryption_salt: "encrypted cookie salt",
    signing_salt: "signing salt"
  ]

  @secret String.duplicate("abcdef0123456789", 8)
  @signing_opts Plug.Session.init(Keyword.put(@default_opts, :encrypt, false))
  @encrypted_opts Plug.Session.init(@default_opts)

  defmodule CustomSerializer do
    def init(_opts), do: "some opts"

    def encode(%{foo: "bar"}, "some opts"), do: {:ok, "encoded session"}
    def encode(%{foo: :bar}, "some opts"), do: {:ok, "another encoded session"}
    def encode(%{}, _), do: {:ok, ""}
    def encode(_, _), do: :error

    def decode("encoded session", "some opts"), do: {:ok, %{foo: "bar"}}
    def decode("another encoded session", "some opts"), do: {:ok, %{foo: :bar}}
    def decode(nil, _), do: {:ok, nil}
    def decode(_, _), do: :error
  end
  @custom_serializer_opts Plug.Session.init(Keyword.put(@default_opts, :serializer, CustomSerializer))

  defp sign_conn(conn, secret \\ @secret) do
    put_in(conn.secret_key_base, secret)
    |> Plug.Session.call(@signing_opts)
    |> fetch_session
  end

  defp encrypt_conn(conn) do
    put_in(conn.secret_key_base, @secret)
    |> Plug.Session.call(@encrypted_opts)
    |> fetch_session
  end

  defp custom_serialize_conn(conn) do
    put_in(conn.secret_key_base, @secret)
    |> Plug.Session.call(@custom_serializer_opts)
    |> fetch_session
  end

  test "requires signing_salt option to be defined" do
    assert_raise ArgumentError, ~r/expects :signing_salt as option/, fn ->
      Plug.Session.init(Keyword.delete(@default_opts, :signing_salt))
    end
  end

  test "requires encrypted_salt option to be defined" do
    assert_raise ArgumentError, ~r/expects :encryption_salt as option/, fn ->
      Plug.Session.init(Keyword.delete(@default_opts, :encryption_salt))
    end
  end

  test "requires the secret to be at least 64 bytes" do
    assert_raise ArgumentError, ~r/to be at least 64 bytes/, fn ->
      conn(:get, "/")
      |> sign_conn("abcdef")
      |> put_session(:foo, "bar")
      |> send_resp(200, "OK")
    end
  end

  test "defaults key generator opts" do
    key_generator_opts = CookieStore.init(@default_opts).key_opts
    assert key_generator_opts[:iterations] == 1000
    assert key_generator_opts[:length] == 32
    assert key_generator_opts[:digest] == :sha256
  end

  test "uses specified key generator opts" do
    opts = @default_opts
            |> Keyword.put(:key_iterations, 2000)
            |> Keyword.put(:key_length, 64)
            |> Keyword.put(:key_digest, :sha)
    key_generator_opts = CookieStore.init(opts).key_opts
    assert key_generator_opts[:iterations] == 2000
    assert key_generator_opts[:length] == 64
    assert key_generator_opts[:digest] == :sha
  end

  test "uses ETF cookie serializer by default" do
    assert Plug.Session.init(@default_opts).store_config.serializer == Plug.Session.COOKIE.ETF
  end

  test "uses custom cookie serializer" do
    assert @custom_serializer_opts.store_config.serializer == CustomSerializer
  end

  ## Signed

  test "session cookies are signed" do
    conn = %{secret_key_base: @secret}
    cookie = CookieStore.put(conn, nil, %{foo: :bar}, @signing_opts.store_config)
    assert is_binary(cookie)
    assert CookieStore.get(conn, cookie, @signing_opts.store_config) == {nil, %{foo: :bar}}
  end

  test "gets and sets signed session cookie" do
    conn = conn(:get, "/")
           |> sign_conn()
           |> put_session(:foo, "bar")
           |> send_resp(200, "")
    assert conn(:get, "/")
           |> recycle(conn)
           |> sign_conn()
           |> get_session(:foo) == "bar"
  end

  test "deletes signed session cookie" do
    conn = conn(:get, "/")
           |> sign_conn()
           |> put_session(:foo, :bar)
           |> configure_session(drop: true)
           |> send_resp(200, "")
    assert conn(:get, "/")
           |> recycle(conn)
           |> sign_conn()
           |> get_session(:foo) == nil
  end

  ## Encrypted

  test "session cookies are encrypted" do
    conn = %{secret_key_base: @secret}
    cookie = CookieStore.put(conn, nil, %{foo: :bar}, @encrypted_opts.store_config)
    assert is_binary(cookie)
    assert CookieStore.get(conn, cookie, @encrypted_opts.store_config) == {nil, %{foo: :bar}}
  end

  test "gets and sets encrypted session cookie" do
    conn = conn(:get, "/")
           |> encrypt_conn()
           |> put_session(:foo, "bar")
           |> send_resp(200, "")
    assert conn(:get, "/")
           |> recycle(conn)
           |> encrypt_conn()
           |> get_session(:foo) == "bar"
  end

  test "deletes encrypted session cookie" do
    conn = conn(:get, "/")
           |> encrypt_conn()
           |> put_session(:foo, :bar)
           |> configure_session(drop: true)
           |> send_resp(200, "")
    assert conn(:get, "/")
           |> recycle(conn)
           |> encrypt_conn()
           |> get_session(:foo) == nil
  end

  ## Custom Serializer

  test "session cookies are serialized by the custom serializer" do
    conn = %{secret_key_base: @secret}
    cookie = CookieStore.put(conn, nil, %{foo: :bar}, @custom_serializer_opts.store_config)
    assert is_binary(cookie)
    assert CookieStore.get(conn, cookie, @custom_serializer_opts.store_config) == {nil, %{foo: :bar}}
  end

  test "gets and sets custom serialized session cookie" do
    conn = conn(:get, "/")
           |> custom_serialize_conn()
           |> put_session(:foo, "bar")
           |> send_resp(200, "")
    assert conn(:get, "/")
           |> recycle(conn)
           |> custom_serialize_conn()
           |> get_session(:foo) == "bar"
  end

  test "deletes custom serialized session cookie" do
    conn = conn(:get, "/")
           |> custom_serialize_conn()
           |> put_session(:foo, :bar)
           |> configure_session(drop: true)
           |> send_resp(200, "")
    assert conn(:get, "/")
           |> recycle(conn)
           |> custom_serialize_conn()
           |> get_session(:foo) == nil
  end

  test "converts serializer reference" do
    opts = Plug.Session.COOKIE.init(@default_opts
            |> Keyword.put(:serializer, :json)
            |> Keyword.put(:json_encoder, CustomSerializer))
    assert opts.serializer == Plug.Session.COOKIE.JSON
  end
end
