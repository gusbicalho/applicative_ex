defmodule ApplicativeTest do
  use ExUnit.Case
  doctest Applicative
  import Applicative

  Module.register_attribute(__MODULE__, :desugaring_case, accumulate: true)

  @desugaring_case {
    "empty",
    quote do
    end,
    nil
  }

  @desugaring_case {
    "one statement with no ok! calls",
    quote do
      a + b + c
    end,
    quote do
      a + b + c
    end
  }

  @desugaring_case {
    "one statement with variables and one ok! call",
    quote do
      a + ok!(b) + c
    end,
    quote do
      with unquote(make_temp_var("temp_", 100)) = a,
           {:ok, unquote(make_temp_var("temp_", 101))} <- b,
           unquote(make_temp_var("temp_", 102)) = c do
        unquote(make_temp_var("temp_", 100)) +
          unquote(make_temp_var("temp_", 101)) +
          unquote(make_temp_var("temp_", 102))
      end
    end
  }

  @desugaring_case {
    "basic case",
    quote do
      foo = ok!(a)
      bar = ok!(b) + ok!(c)
      foo + bar
    end,
    quote do
      with {:ok, unquote(make_temp_var("temp_", 100))} <- a,
           foo = unquote(make_temp_var("temp_", 100)),
           {:ok, unquote(make_temp_var("temp_", 101))} <- b,
           {:ok, unquote(make_temp_var("temp_", 102))} <- c,
           bar =
             unquote(make_temp_var("temp_", 101)) +
               unquote(make_temp_var("temp_", 102)) do
        foo + bar
      end
    end
  }

  for {name, sugared, desugared} <- @desugaring_case do
    test "desugaring #{name}" do
      expected = unquote({:quote, [], [[{:do, desugared}]]})

      assert expected ==
               desugar_ok?(
                 unquote({:quote, [], [[{:do, sugared}]]}),
                 %{
                   temp_var_prefix: "temp_",
                   temp_var_id_init: 100,
                   marker: :ok!
                 }
               )
    end
  end

  test "run basic case" do
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
    assert ^result =
             (with {:ok, temp_1} <- a,
                   foo = temp_1,
                   {:ok, temp_2} <- b,
                   {:ok, temp_3} <- c,
                   bar = temp_2 + temp_3 do
                foo + bar
              end)
  end
end
