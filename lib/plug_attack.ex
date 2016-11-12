defmodule PlugAttack do
  @moduledoc """
  A plug building toolkit for blocking and throttling abusive requests.

  PlugAttack is a set of macros that can be used to build a plug to protect
  your web app from bad clients. It allows safelisting, blocklisting and
  throttling based on arbitrary properties of the request.

  The throttling state is stored in a configurable storage.
  By default an implementation backed by `:ets` tables is offered.

  ## Example

      defmodule MyApp.PlugAttack do
        use PlugAttack

        # For more rules examples see `PlugAttack.rule/2` macro documentation.
        rule "allow local", conn do
          allow conn.remote_ip == {127, 0, 0, 1}
        end

        # It's possible to customize what happens when conn is let through
        def allow_action(conn, _data, _opts), do: conn

        # Or when it's blocked
        def block_action(conn, _data, _opts) do
          conn
          |> send_resp(:forbidden, "Forbidden\n")
          |> halt
        end
      end
  """

  @typedoc """
  The rule return value.
  """
  @type rule :: {:allow, term} | {:block, term} | nil

  @doc """
  Action performed when the request is blocked.
  """
  @callback block_action(Plug.Conn.t, term, term) :: Plug.Conn.t

  @doc """
  Action performed when the request is allowed.
  """
  @callback allow_action(Plug.Conn.t, term, term) :: Plug.Conn.t

  defmacro __using__(opts) do
    quote do
      @behaviour Plug
      @behaviour PlugAttack
      @plug_attack_opts unquote(opts)

      def init(opts) do
        opts
      end

      def call(conn, opts) do
        plug_attack_call(conn, opts)
      end

      def block_action(conn, _data, _opts) do
        conn
        |> send_resp(:forbidden, "Forbidden\n")
        |> halt
      end

      def allow_action(conn, _data, _opts) do
        conn
      end

      defoverridable [init: 1, call: 2, block_action: 3, allow_action: 3]

      import PlugAttack, only: [rule: 2, rule: 3]

      Module.register_attribute(__MODULE__, :plug_attack, accumulate: true)
      @before_compile PlugAttack
    end
  end

  @doc false
  defmacro __before_compile__(%{module: module} = env) do
    plug_attack = Module.get_attribute(module, :plug_attack)

    {conn, opts, body} = PlugAttack.compile(env, plug_attack)
    quote do
      defp plug_attack_call(unquote(conn), unquote(opts)), do: unquote(body)
    end
  end

  @doc """
  Defines a rule.

  A rule is an expression that returns either `{:allow, data}`, `{:block, data}`,
  or `nil`. If an allow or block tuple is returned we say the rule *matched*,
  otherwise the rule didn't match and further rules will be evaluated.

  If a rule matched the corresponding `allow_action/3` or `block_action/3`
  function on the defining module will be called passing the `conn`,
  the `data` value from the allow or block tuple and `opts` as returned by the
  `init/1` plug callback. If none rule matched, neither `allow_action/3` nor
  `block_action/3` will be called.

  Both actions should behave similarly to plugs, returning the modified
  `conn` argument. The default implementation of `allow_action/3` will
  return the conn unmodified. The default implementation of `block_action/3`
  will respond with status 403 Forbidden, the body `"Forbidden\n"` and halt
  the plug pipeline.

  Various predefined rules are defined in the `PlugAttack.Rule` module.
  This module is automatically imported in the rule's body.

  ## Examples

      rule "allow local", conn do
        allow conn.remote_ip == {127, 0, 0, 1}
      end

      rule "block 1.2.3.4", conn do
        block conn.remote_ip == {1, 2, 3, 4}
      end

      rule "throttle per ip", conn do
        # throttle to 5 requests per second
        throttle conn.remote_ip,
          period: 1_000, limit: 5,
          storage: {PlugAttack.Storage.Ets, MyApp.PlugAttack.Storage}
      end

      rule "throttle login requests", conn do
        if conn.method == "POST" and conn.path_info == ["login"] do
          throttle conn.params["email"],
            period: 60_000, limit: 10,
            storage: {PlugAttack.Storage.Ets, MyApp.PlugAttack.Storage}
        end
      end
  """
  defmacro rule(message, var \\ quote(do: _), contents) do
    contents =
      case contents do
        [do: block] ->
          quote do
            import PlugAttack.Rule
            unquote(block)
          end
        _ ->
          quote do
            import PlugAttack.Rule
            try(unquote(contents))
          end
      end

    var      = Macro.escape(var)
    contents = Macro.escape(contents, unquote: true)

    quote bind_quoted: [message: message, var: var, contents: contents] do
      name = PlugAttack.register(__MODULE__, message)
      defp unquote(name)(unquote(var)), do: unquote(contents)
    end
  end

  @doc false
  def register(module, message) do
    name = :"rule #{message}"
    Module.put_attribute(module, :plug_attack, name)
    name
  end

  @doc false
  def compile(env, rules) do
    conn = quote(do: conn)
    opts = quote(do: opts)
    body = Enum.reduce(rules, conn, &quote_rule(&2, &1, conn, opts, env))
    {conn, opts, body}
  end

  defp quote_rule(next, name, conn, opts, _env) do
    quote do
      case unquote(name)(unquote(conn)) do
        {:allow, data} -> allow_action(unquote(conn), data, unquote(opts))
        {:block, data} -> block_action(unquote(conn), data, unquote(opts))
        nil            -> unquote(next)
        other ->
          raise "a PlugAttack rule should return `{:allow, data}`, " <>
            "`{:block, data}`, or `nil`, got: #{inspect other}"
      end
    end
  end
end
