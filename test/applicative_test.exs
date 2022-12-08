defmodule ApplicativeTest do
  use ExUnit.Case
  doctest Applicative
  import Applicative
  alias Applicative.NotOk

  test "basic case" do
    a = {:ok, 4}
    b = {:ok, 7}
    c = {:ok, 8}
    ok_tag = &{:ok, &1}

    assert 19 ==
             (ok? do
                foo = ok!(a)
                bar = ok!(ok_tag.(ok!(b) + ok!(c)))
                foo + bar
              end)
  end
end
