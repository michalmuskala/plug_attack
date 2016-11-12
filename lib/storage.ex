defmodule PlugAttack.Storage do
  @moduledoc """
  Behaviour for the storage backend for various rules.
  """

  @type key :: {atom, term, integer}
  @type expires_at :: non_neg_integer
  @type opts :: term

  @callback increment(opts, key, inc :: integer, expires_at) :: integer
end
