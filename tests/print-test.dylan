module: print-test
author: David Watson, Nick Kramer
synopsis: Test for the print library.
copyright: See below.

//======================================================================
//
// Copyright (c) 1996  Carnegie Mellon University
// Copyright (c) 1998, 1999, 2000  Gwydion Dylan Maintainers
// All rights reserved.
// 
// Use and copying of this software and preparation of derivative
// works based on this software are permitted, including commercial
// use, provided that the following conditions are observed:
// 
// 1. This copyright notice must be retained in full on any copies
//    and on appropriate parts of any derivative works.
// 2. Documentation (paper or online) accompanying any system that
//    incorporates this software, or any part of it, must acknowledge
//    the contribution of the Gwydion Project at Carnegie Mellon
//    University, and the Gwydion Dylan Maintainers.
// 
// This software is made available "as is".  Neither the authors nor
// Carnegie Mellon University make any warranty about the software,
// its performance, or its conformity to any specification.
// 
// Bug reports should be sent to <gd-bugs@gwydiondylan.org>; questions,
// comments and suggestions are welcome at <gd-hackers@gwydiondylan.org>.
// Also, see http://www.gwydiondylan.org/ for updates and documentation. 
//
//======================================================================

define variable has-errors = #f;

define method run-several-tests (test-name :: <string>, 
                                 test :: <function>)
 => ();
  format-out("%s ... ", test-name);
  let temp-has-errors = has-errors;
  has-errors := #f;
  test();
  if (has-errors == #f)
    format-out("ok.\n");
  end if;
  has-errors := temp-has-errors | has-errors;
end method run-several-tests;

define method run-test (input, expected-result, test-name :: <string>)
 => passed? :: <boolean>;
  if (input ~= expected-result)
    has-errors := #t;
    format-out("Failed %s!\n", test-name);
    format-out("     Got %=\n", input);
    format-out("     when we expected %=\n", expected-result);
    #f;
  else
    #t;
  end if;
end method run-test;

define method print-test () => ();
  run-test(print-to-string(42), "42", "integer");
  run-test(print-to-string(-1), "-1", "negative integer");
  run-test(print-to-string("Hello"), "\"Hello\"", "string");

  let eint :: <extended-integer> = as(<extended-integer>, -1);
  run-test(print-to-string(eint), "-1", "extended-integer");
	   
  let sequence-1 = make(<stretchy-vector>);
  run-test(print-to-string(sequence-1), "{stretchy vector }",
	   "empty sequence");

  let sequence-2 = make(<stretchy-vector>, size: 5);
  sequence-2[3] := 3;
  run-test(print-to-string(sequence-2),
	   "{stretchy vector #f, #f, #f, 3, #f}", "sequence");

  let sequence-3 = #[4, 5, 6, 2];
  run-test(print-to-string(sequence-3), "#[4, 5, 6, 2]", "vector");

  let deque-1 = make(<deque>);
  push(deque-1, 4);
  push(deque-1, 5);
  run-test(print-to-string(deque-1), "{deque of 5, 4}", "deque");

  let table-1 = make(<table>);
  table-1[5] := 42;
  run-test(print-to-string(table-1), "{instance of {class <simple-object-table>}}", "table");

  let range-1 = make(<range>);
  run-test(print-to-string(range-1), "{range 0 by 1}", "range");
  
  let range-2 = make(<range>, from: 0, to: 0);
  run-test(print-to-string(range-2), "{range 0 through 0 by 1}", "0 range");

  let range-3 = make(<range>, from: 0, to: -20, by: -2);
  run-test(print-to-string(range-3), "{range 0 through -20 by -2}",
	   "negative range");

  let array-1 = make(<array>, dimensions: #[2, 2]);
  for (i from 0 below 2)
    for (j from 0 below 2)
      array-1[i, j] := row-major-index(array-1, i, j);
    end for;
  end for;
  run-test(print-to-string(array-1), "{instance of {class <simple-object-array>}}", "array");

   let float-1 = 10.0s0;
   run-test(print-to-string(float-1), "10.0", "float");

   let double-float-1 = 10.0d0;
   run-test(print-to-string(double-float-1), "10.0", "double-float");
end method print-test;

define method main (argv0, #rest ignored)
  format-out("\nRegression test for the print library.\n\n");
  run-several-tests("print", print-test);
  if (has-errors)
    format-out("\n********* Warning!  Regression test failed! ***********\n");
  else
    format-out("All print tests pass.\n");
  end if;
end method main;