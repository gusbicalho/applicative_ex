defmodule ApplicativeTest do
  use ExUnit.Case
  doctest Applicative
  import Applicative
  alias Applicative.NotOk

  test "basic case" do
    a = {:ok, 4}
    b = {:ok, 7}
    c = {:ok, 8}

    assert 19 ==
             (ok? do
                foo = ok!(a)
                bar = ok!(b) + ok!(c)
                foo + bar
              end)
  end
end
