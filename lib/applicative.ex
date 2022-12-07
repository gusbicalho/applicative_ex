defmodule Applicative do
  @moduledoc """
  Documentation for `Applicative`.
  """

  defp desugar_statement(form, opts) do
    {steps, desugared_form} = desugar_expression(form, opts)
    steps ++ [desugared_form]
  end

  def desugar_expression({:=, _meta, [pattern, expression]}, opts) do
    {steps, desugared_expression} = desugar_expression(expression, opts)

    {steps,
     quote do
       unquote(pattern) = unquote(desugared_expression)
     end}
  end

  def desugar_expression({marker, _meta, [ok_form]}, %{marker: marker}) do
    var = fresh()

    {[
       quote generated: true do
         {:ok, unquote(var)} <- unquote(ok_form)
       end
     ], var}
  end

  def desugar_expression({:fn, _, _} = lambda, _opts) do
    {[], lambda}
  end

  def desugar_expression({f, meta, [_ | _] = args}, opts) do
    {many_steps, desugared_args} =
      args
      |> Enum.map(&desugar_expression(&1, opts))
      |> Enum.unzip()

    {Enum.concat(many_steps), {f, meta, desugared_args}}
  end

  def desugar_expression(todo, _opts) do
    {[], todo}
  end

  def fresh(prefix \\ "fresh_") do
    i = :erlang.unique_integer([:positive])
    {String.to_atom("#{prefix}#{i}"), [], __MODULE__}
  end

  defp pop_last(list) do
    case Enum.reverse(list) do
      [] -> nil
      [x | rev_front] -> {Enum.reverse(rev_front), x}
    end
  end

  defmacro applicative(opts \\ [], do: do_block) do
    marker = Keyword.get(opts, :marker, :ap!)

    statements =
      case do_block do
        {:__block__, _, statements} -> statements
        other_form -> [other_form]
      end

    statements
    |> Macro.expand(__ENV__)
    |> Enum.flat_map(&desugar_statement(&1, %{marker: marker}))
    |> pop_last()
    |> case do
      nil -> quote do: nil
      {[], last_expr} -> last_expr
      {steps, last_expr} -> {:with, [], steps ++ [[{:do, last_expr}]]}
    end
  end

  def test() do
    a = {:ok, 4}
    b = {:ok, 7}
    c = {:ok, 8}

    applicative do
      foo = ap!(a)
      bar = ap!(b) + ap!(c)
      foo + bar
    end
    |> IO.inspect(label: "applicative")

    # desugars to
    with {:ok, fresh_1} <- a,
         foo = fresh_1,
         {:ok, fresh_2} <- b,
         {:ok, fresh_3} <- c,
         bar = fresh_2 + fresh_3 do
      foo + bar
    end
    |> IO.inspect(label: "raw with")

    nil
  end
end
