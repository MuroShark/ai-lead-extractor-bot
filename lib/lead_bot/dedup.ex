defmodule LeadBot.Dedup do
  @moduledoc """
  Short-window de-duplication so the bot never answers the same message twice.

  Backed by a public ETS table keyed by `{chat_id, fingerprint}` with a TTL.
  A periodic sweep drops expired entries so the table can't grow unbounded.
  Survives Telegram redelivering an update after a crash mid-processing.
  """

  use GenServer

  @table :lead_bot_dedup
  @ttl_ms :timer.minutes(10)
  @sweep_ms :timer.minutes(1)

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Returns `:new` the first time a key is seen within the TTL window and marks
  it; `:duplicate` for a repeat within the window.
  """
  @spec check_and_mark(term()) :: :new | :duplicate
  def check_and_mark(key) do
    now = System.monotonic_time(:millisecond)

    if :ets.insert_new(@table, {key, now}) do
      :new
    else
      case :ets.lookup(@table, key) do
        [{^key, ts}] when now - ts < @ttl_ms ->
          :duplicate

        _ ->
          :ets.insert(@table, {key, now})
          :new
      end
    end
  end

  @doc "Forget a key so it can be processed again (e.g. after a failed attempt)."
  @spec forget(term()) :: :ok
  def forget(key) do
    :ets.delete(@table, key)
    :ok
  end

  @impl true
  def init(_opts) do
    _table =
      :ets.new(@table, [
        :named_table,
        :public,
        :set,
        read_concurrency: true,
        write_concurrency: true
      ])

    schedule_sweep()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sweep, state) do
    cutoff = System.monotonic_time(:millisecond) - @ttl_ms
    :ets.select_delete(@table, [{{:_, :"$1"}, [{:<, :"$1", cutoff}], [true]}])
    schedule_sweep()
    {:noreply, state}
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_ms)
end
