defmodule PlugAttack.Storage do
  @moduledoc """
  Behaviour for the storage backend for various rules.
  """

  @type key :: term
  @typedoc """
  Time of milliseconds since unix epoch.
  """
  @type time :: non_neg_integer
  @type opts :: term

  @callback increment(opts, key, inc :: integer, expires_at :: time) :: integer

  @callback write_sliding_counter(opts, key, expires_at :: time) :: :ok

  @callback read_sliding_counter(opts, key, now :: time) :: non_neg_integer

  @callback write(opts, key, value :: term, expires_at :: time) :: :ok

  @callback read(opts, key, now :: time) :: {:ok, term} | :error
end
