defmodule PlugAttack do
  defmacro __using__(opts) do
    quote do
      @behaviour Plug
      @plug_attack_opts unquote(opts)

      def init(opts) do
        opts
      end

      def call(conn, opts) do
        plug_attack_call(conn, opts)
      end

      def block_action(conn, _data, _opts) do
        conn
        |> send_resp(:forbidden, "Forbidden!\n")
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
    opts         = Module.get_attribute(module, :plug_attack_opts)
    plug_attack  = Module.get_attribute(module, :plug_attack)

    {conn, body} = PlugAttack.compile(env, plug_attack, opts)
    quote do
      defp plug_attack_call(unquote(conn), _), do: unquote(body)
    end
  end

  defmacro rule(message, var \\ quote(do: _), [do: body]) do
    var      = Macro.escape(var)
    contents = Macro.escape(body)

    quote bind_quoted: binding() do
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
  def compile(env, rules, opts) do
    conn = quote(do: conn)
    body = Enum.reduce(rules, conn, &quote_rule(&2, &1, conn, env, opts))
    {conn, body}
  end

  defp quote_rule(next, name, conn, _env, plug_opts) do
    quote do
      case unquote(name)(unquote(conn)) do
        {:allow, data} -> allow_action(unquote(conn), data, unquote(plug_opts))
        {:block, data} -> block_action(unquote(conn), data, unquote(plug_opts))
        nil            -> unquote(next)
      end
    end
  end
end
