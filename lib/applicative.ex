defmodule Applicative do
  @moduledoc """
  Documentation for `Applicative`.
  """

  defmodule NotOk do
    defstruct [:value]
  end

  defp desugar_expression({:=, meta, [pattern, expression]}, opts) do
    desugared_expression = desugar_expression(expression, opts)

    {:=, meta, [pattern, desugared_expression]}
  end

  defp desugar_expression({marker, _meta, [expression]}, %{marker: marker} = opts) do
    expression = Macro.expand(expression, opts.env)
    desugared_expression = desugar_expression(expression, opts)

    quote do
      case unquote(desugared_expression) do
        {:ok, unquote(temp_var())} -> unquote(temp_var())
        unquote(temp_var()) -> throw(%NotOk{value: unquote(temp_var())})
      end
    end
  end

  defp desugar_expression({:fn, _, _} = lambda_form, _opts) do
    lambda_form
  end

  defp desugar_expression({:quote, _, _} = quote_form, _opts) do
    quote_form
  end

  defp desugar_expression(form, opts) do
    case Macro.expand(form, opts.env) do
      {f, meta, [_ | _] = args} ->
        {f, meta, Enum.map(args, &desugar_expression(&1, opts))}

      other ->
        other
    end
  end

  defp temp_var() do
    quote(do: temp)
  end

  def desugar_ok?(form, opts) do
    quote do
      try do
        unquote(desugar_expression(form, opts))
      catch
        %NotOk{value: unquote(temp_var())} -> unquote(temp_var())
      end
    end
  end

  defmacro ok?(opts \\ [], do: do_block) do
    %{file: file, line: line, module: module} = __CALLER__

    desugar_ok?(do_block, %{
      env: __CALLER__,
      context: %{file: file, line: line, module: module},
      marker: Keyword.get(opts, :marker, :ok!)
    })
  end

  defmacro ok!(_) do
    raise %CompileError{
      description: "ok! called outside ok? block",
      line: __CALLER__.line,
      file: __CALLER__.file
    }
  end

  # def bad_ok do
  #   ok!({:ok, 7})
  # end
end
