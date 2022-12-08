defmodule Applicative do
  @moduledoc """
  Documentation for `Applicative`.
  """

  defmodule DesugaringState do
    @enforce_keys [:next_temp_id]
    defstruct [:next_temp_id]
  end

  defp desugar_statement(form, %DesugaringState{} = state, opts) do
    {new_state, steps, result_form} = desugar_expression(form, state, opts)

    if Enum.any?(steps, &match?({:<-, _, _}, &1)) do
      {new_state, steps, result_form}
    else
      {state, [], form}
    end
  end

  defp desugar_expression({:=, _meta, [pattern, expression]}, %DesugaringState{} = state, opts) do
    {state, steps, desugared_expression} = desugar_expression(expression, state, opts)

    {state, steps,
     quote do
       unquote(pattern) = unquote(desugared_expression)
     end}
  end

  defp desugar_expression({marker, _meta, [ok_form]}, %DesugaringState{} = state, %{
         marker: marker,
         temp_var_prefix: temp_var_prefix
       }) do
    {state, var} = temp(state, temp_var_prefix)

    {state,
     [
       quote do
         {:ok, unquote(var)} <- unquote(ok_form)
       end
     ], var}
  end

  defp desugar_expression({:fn, _, _} = lambda, state, _opts) do
    {state, [], lambda}
  end

  defp desugar_expression({:quote, _, _} = lambda, state, _opts) do
    {state, [], lambda}
  end

  defp desugar_expression({f, meta, [_ | _] = args}, %DesugaringState{} = state, opts) do
    {state, steps, desugared_args} =
      args
      |> Enum.reduce({state, [], []}, fn arg_form,
                                         {state, reverse_many_steps, reverse_desugared_args} ->
        {state, steps, desugared_arg} = desugar_expression(arg_form, state, opts)
        {state, [steps | reverse_many_steps], [desugared_arg | reverse_desugared_args]}
      end)
      |> then(fn {state, reverse_many_steps, reverse_desugared_args} ->
        {state, Enum.concat(Enum.reverse(reverse_many_steps)),
         Enum.reverse(reverse_desugared_args)}
      end)

    {state, steps, {f, meta, desugared_args}}
  end

  defp desugar_expression(other, state, %{temp_var_prefix: temp_var_prefix}) do
    {state, var} = temp(state, temp_var_prefix)

    {state,
     [
       quote do
         unquote(var) = unquote(other)
       end
     ], var}
  end

  defp temp(%DesugaringState{} = state, prefix) do
    i = state.next_temp_id
    var = make_temp_var(prefix, i)
    {put_in(state.next_temp_id, i + 1), var}
  end

  def make_temp_var(prefix, temp_id) do
    {String.to_atom("#{prefix}#{temp_id}"), [], __MODULE__}
  end

  defp pop_last(list) do
    case Enum.reverse(list) do
      [] -> nil
      [x | rev_front] -> {Enum.reverse(rev_front), x}
    end
  end

  def desugar_ok?(
        form,
        %{temp_var_prefix: temp_var_prefix, temp_var_id_init: temp_var_id_init, marker: marker}
      ) do
    init_desugaring_state = %DesugaringState{
      next_temp_id: temp_var_id_init
    }

    statements =
      case form do
        {:__block__, _, statements} -> statements
        other_form -> [other_form]
      end

    statements
    |> Macro.expand(__ENV__)
    |> Enum.scan({init_desugaring_state, nil, nil}, fn statement, {desugaring_state, _, _} ->
      desugar_statement(statement, desugaring_state, %{
        marker: marker,
        temp_var_prefix: temp_var_prefix
      })
    end)
    # |> Enum.flat_map(fn {_, steps, final_step} -> desugared_forms end)
    |> pop_last()
    |> case do
      nil ->
        quote do: nil

      {[], {_, [], final_result}} ->
        final_result

      {desugared_statements, {_, final_steps, final_result}} ->
        steps =
          Enum.flat_map(desugared_statements, fn
            {_, steps, result} ->
              result_step =
                case result do
                  {op, _, _} when op in [:<-, :=] -> result
                  _other -> quote(do: _ = unquote(result))
                end

              steps ++ [result_step]
          end) ++
            final_steps

        {:with, [], steps ++ [[{:do, final_result}]]}
    end
  end

  defmacro ok?(opts \\ [], do: do_block) do
    desugar_ok?(do_block, %{
      temp_var_prefix: Keyword.get(opts, :temp_var_prefix, "temp_"),
      temp_var_id_init:
        Keyword.get_lazy(opts, :temp_var_id_init, fn -> :erlang.unique_integer([:positive]) end),
      marker: Keyword.get(opts, :marker, :ok!)
    })
  end

  def test() do
    a = {:ok, 4}
    b = {:ok, 7}
    c = {:ok, 8}

    result =
      ok? do
        foo = ok!(a)
        bar = ok!(b) + ok!(c)
        foo + bar
      end

    # desugars to
    ^result =
      with {:ok, temp_1} <- a,
           foo = temp_1,
           {:ok, temp_2} <- b,
           {:ok, temp_3} <- c,
           bar = temp_2 + temp_3 do
        foo + bar
      end
  end
end
