module: backend
author: Matthias Hölzl
copyright: see below

//======================================================================
//
// Copyright (c) 1995 - 1997  Carnegie Mellon University
// Copyright (c) 1998 - 2011  Gwydion Dylan Maintainers
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

// This file defines an open abstract class <compiler-backend> that
// serves to decouple the core of the compiler from backend-specific
// details.


// <compiler-backend> --exported
//
// The abstract superclass of all compiler backends.  Each backend
// should define a subtype of this class and implement the backend
// protocol.
//
define open abstract class <compiler-backend> (<object>)
  slot backend-name :: <symbol>,
    required-init-keyword: name:;
end class <compiler-backend>;


// *all-backends* -- internal
//
// All currently registered compiler backends.
//
define variable *all-backends* :: <stretchy-vector>
  = make(<stretchy-vector>);


// find-backend -- exported
//
// Find a (registered) backend.
//
define generic find-backend
    (backend-or-name :: type-union(<symbol>, <compiler-backend>))
 => (backend :: false-or(<compiler-backend>));

// find-backend -- exported
//
// Return backend, if it is registered.
//
define method find-backend
    (backend :: <compiler-backend>) => (backend :: false-or(<compiler-backend>));
  member?(backend, *all-backends*) & backend;
end method find-backend;

// find-backend -- exported
//
// Return the registered backend with backend-name name if it is
// registered, #f otherwise.
//
define method find-backend
    (name :: <symbol>) => (backend :: false-or(<compiler-backend>));
  find(*all-backends*, method (backend)
                         backend.backend-name = name;
                       end);
end method find-backend;


// register-compiler-backend -- exported
//
// Register a compiler backend.
//
define function register-compiler-backend
    (backend :: <compiler-backend>, #key replace-existing-backend = #f)
 => ();
  let existing = find-backend(backend.backend-name);
  if (existing & ~replace-existing-backend)
    internal-warning("Replacing existing backend %s.",
                     backend.backend-name);
  end if;
  *all-backends* := add!(*all-backends*, backend);
end function register-compiler-backend;


// all-compiler-backends -- exported
//
// Return a sequence of all registered backends.
//
define function all-compiler-backends () => (backends :: <simple-vector>);
  as(<simple-vector>, *all-backends*);
end function all-compiler-backends;


// all-compiler-backend-names -- exported
//
// Return a sequence of all names of registered backends.
//
define function all-compiler-backend-names () => (names :: <sequence>);
  map(backend-name, all-compiler-backends());
end function all-compiler-backend-names;

// *backend* -- internal
//
// The current compiler backend.
//
define variable *backend* :: false-or(<compiler-backend>) = #f;

// compiler-backend -- exported
//
// Return the current compiler backend.  Throws an error if no backend
// was previously set.
//
define function compiler-backend () => (backend :: <compiler-backend>);
  assert(*backend*,
         "The compiler backend must be set before using it.");
  *backend*;
end function compiler-backend;

// compiler-backend-setter -- exported
//
// Sets the current compiler backend, registering it if necessary.
//
define function compiler-backend-setter
    (new-backend :: <compiler-backend>)
 => (new-backend :: <compiler-backend>);
  let name = new-backend.backend-name;
  let backend-for-name = find-backend(name);
  let registered? = (backend-for-name = new-backend);
  if (~registered?)
    if (backend-for-name)
      internal-warning("Replacing backend named %s.", name);
    end if;
    register-compiler-backend(new-backend);
  end if;
  *backend* := new-backend;
end function compiler-backend-setter;
