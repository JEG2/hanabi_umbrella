defmodule HanabiStorage.SerializedField do
  @behaviour Ecto.Type

  def type, do: :binary

  def cast(term), do: {:ok, term}

  def dump(term), do: {:ok, :erlang.term_to_binary(term)}

  def load(binary), do: {:ok, :erlang.binary_to_term(binary)}
end
