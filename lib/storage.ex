defmodule PlugAttack.Storage do
  @type key :: {term, integer}
  @type expires_at :: non_neg_integer
  @type opts :: term

  @callback start_link(opts) :: GenServer.on_start
  @callback increment(opts, key, inc :: integer, expires_at) :: integer
end
