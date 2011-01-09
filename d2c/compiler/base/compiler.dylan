module: compiler
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

// This file defines the overall structure of the compiler: instances
// of the abstract open class <compiler> holds information about the
// compilation options, the available frontends and backends, the
// currently selected instances of front- and backend, etc.  The class
// <simple-compiler> represents the default implementation of the
// compiler protocol.  The open abstract classes <compiler-frontend>
// and <compiler-backend> serve to decouple the core of the compiler
// from language- and backend-specific details.

/// The Compiler Class
/// ==================

// <compiler> -- exported
//
// The abstact superclass of all compilers.  All subclasses need to
// implement the compiler protocol specified below.
//
define abstract open class <compiler> (<object>)
end class <compiler>;


/// The Compiler Protocol.
/// ---------------------

// configuration -- exported
//
// The configuration for the compiler; either provided by command-line
// arguments, by a configuration file, by default or interactively.
//
define open generic configuration
    (compiler :: <compiler>) => (res :: <explicit-key-collection>);

// active-frontend -- exported
//
// The frontend currently used to process compilation units.
//
define open generic active-frontend
    (compiler :: <compiler>) => (res :: <compiler-frontend>);

// active-frontend-setter -- exported
//
// Changes the frontend currently used to process compilation units.
// The frontend must have been registered before, i.e., it must be a
// member of all-active-frontends.
//
define open generic active-frontend-setter
    (new-frontend :: <compiler-frontend>, compiler :: <compiler>,
     #key replace-if-exists? :: <boolean>)
 => (new-frontend :: <compiler-frontend>);

// all-frontends -- exported
//
// All frontends available for this compiler.
//
// ### The result type should be
//     limited(<vector>, of: <compiler-frontend>)
//     but GD doesn't grok this yet.
//
define open generic all-frontends
    (compiler :: <compiler>) => (res :: <vector>);

// all-frontend-names -- exported
//
// Return a sequence of all names of registered frontends for compiler.
//
define function all-frontend-names
    (compiler :: <compiler>) => (names :: <sequence>);
  map(frontend-name, all-frontends(compiler));
end function all-frontend-names;

// active-backend -- exported
//
// The backend currently used to process compilation units.
//
define open generic active-backend
    (compiler :: <compiler>) => (res :: <compiler-backend>);

// active-backend-setter -- exported
//
// Changes the backend currently used to process compilation units.
// The backend must have been registered before, i.e., it must be a
// member of all-active-backends.
//
define open generic active-backend-setter
    (new-backend :: <compiler-backend>, compiler :: <compiler>,
     #key replace-if-exists? :: <boolean>)
 => (new-backend :: <compiler-backend>);

// all-backends -- exported
//
// All backends available for this compiler.
//
// ### The result type should be
//     limited(<vector>, of: <compiler-backend>)
//     but GD doesn't grok this yet.
//
define open generic all-backends
    (compiler :: <compiler>) => (res :: <vector>);

// all-backend-names -- exported
//
// Return a sequence of all names of registered backends for compiler.
//
define function all-backend-names
    (compiler :: <compiler>) => (names :: <sequence>);
  map(backend-name, all-backends(compiler));
end function all-backend-names;

// find-frontend -- exported
//
// Find the designated frontend for compiler; return false if no such
// frontend exists.
//
define open generic find-frontend
    (compiler :: <compiler>, frontend :: <compiler-frontend-designator>)
 => (frontend :: false-or(<compiler-frontend>), index :: false-or(<integer>));

// register-frontend -- exported
//
// Register a frontend with compiler, i.e., ensure that it will be
// returned by future calls of all-frontends.  If the frontend is
// already registered with the compiler, the function completes
// normally without performing any changes to the compiler.  The
// behavior of this function is undefined if the frontend is not
// compatible with the compiler.
//
define open generic register-frontend
    (compiler :: <compiler>, frontend :: <compiler-frontend>)
 => ();

// find-backend -- exported
//
// Find the designated backend for compiler; return false if no such
// backend exists.
//
define open generic find-backend
    (compiler :: <compiler>, backend :: <compiler-backend-designator>)
 => (backend :: false-or(<compiler-backend>), index :: false-or(<integer>));

// find-backend -- method on exported GF
//
// Return backend, if it is registered.
//
define method find-backend
    (compiler :: <compiler>, backend :: <compiler-backend>)
 => (backend :: false-or(<compiler-backend>), index :: false-or(<integer>));
  let key :: false-or(<integer>) = key-of(backend, compiler.all-backends);
  if (key)
    values(backend, key);
  else
    values(#f, #f);
  end if;
end method find-backend;

// find-backend -- method on exported GF
//
// Return the registered backend with backend-name name if it is
// registered, #f otherwise.
//
define method find-backend
    (compiler :: <compiler>, name :: <symbol>)
 => (backend :: false-or(<compiler-backend>), index :: false-or(<integer>));
  find-member(name, compiler.all-backends, key: backend-name);
end method find-backend;



// register-backend -- exported
//
// Register a backend with compiler, i.e., ensure that it will be
// returned by future calls of all-backends.  If the backend is
// already registered with the compiler, the function completes
// normally without performing any changes to the compiler.  The
// behavior of this function is undefined if the backend is not
// compatible with the compiler.
//
define open generic register-backend
    (compiler :: <compiler>, backend :: <compiler-backend>,
     #key replace-if-exists? :: <boolean>)
 => ();

// register-backend -- method on exported GF
//
define method register-backend
    (compiler :: <compiler>, backend :: <compiler-backend>,
     #key replace-if-exists? :: <boolean> = #f)
 => ();
  let name = backend.backend-name;
  let (existing-backend, index) = find-backend(compiler, name);
  if (existing-backend)
    let different-backends? = (existing-backend ~= backend);
    if (different-backends?)
      if (~replace-if-exists?)
        internal-warning("Replacing backend named %s.", name);
      end if;
      compiler.all-backends[index] := backend;
    end if;
  else
    compiler.all-backends := add!(compiler.all-backends, backend);
  end if;
end method register-backend;


// *active-compiler* -- internal
//
// The variable used to store the compiler we currently use to compile
// code; false if no compiler has been defined, yet.
//
define variable *active-compiler* :: false-or(<compiler>) = #f;

// active-compiler -- exported
//
// The compiler we currently use to compile code; false if no compiler
// has been defined, yet.
//
define function active-compiler () => (res :: <compiler>);
  assert(*active-compiler*,
         "Trying to use the active compiler before defining it.");
  *active-compiler*;
end function active-compiler;

// active-compiler-setter -- exported
//
// Set the compiler we currently use to compile code.
//
define function active-compiler-setter
    (new-compiler :: <compiler>) => (new-compiler :: <compiler>);
  *active-compiler* := new-compiler;
end function active-compiler-setter;



/// Simple Compiler.
/// ===============

// Simple compilers implement the compiler protocol in a
// straightforward manner.
//
define open class <simple-compiler> (<compiler>)
  slot configuration :: <table> = make(<table>),
    init-keyword: configuration:;
  slot active-frontend :: <compiler-frontend>,
    required-init-keyword: active-frontend:,
    setter: %active-frontend-setter;
  slot all-frontends :: <vector> = make(<stretchy-vector>),
    init-keyword: all-frontends:;
  slot active-backend :: <compiler-backend>,
    required-init-keyword: active-backend:,
    setter: %active-backend-setter;
  slot all-backends :: <vector> = make(<stretchy-vector>),
    init-keyword: all-backends:;
end class <simple-compiler>;


// active-frontend-setter -- exported
//
// Sets the active frontend, registering it if necessary.
//
define method active-frontend-setter
    (new-frontend :: <compiler-frontend>, compiler :: <simple-compiler>,
     #key replace-if-exists? :: <boolean> = #f)
 => (new-frontend :: <compiler-frontend>);
  assert(member?(new-frontend, compiler.all-frontends),
         "Can't activate frontend %= for compiler %s "
           "because it is not registered.",
         new-frontend, compiler);
  compiler.%active-frontend := new-frontend;
end method active-frontend-setter;

// active-backend-setter -- exported
//
// Sets the active backend, registering it if necessary.
//
define method active-backend-setter
    (new-backend :: <compiler-backend>, compiler :: <simple-compiler>,
     #key replace-if-exists? :: <boolean> = #f)
 => (new-backend :: <compiler-backend>);
  assert(member?(new-backend, compiler.all-backends),
         "Can't activate backend %= for compiler %s "
           "because it is not registered.",
         new-backend, compiler);
  compiler.%active-backend := new-backend;
end method active-backend-setter;



// <compiler-frontend> -- exported
//
// The abstract superclass of all compiler frontends.  Each frontend
// should define a subtype of this class and implement the frontend
// protocol (to be defined later).
//
define abstract open class <compiler-frontend> (<object>)
  slot frontend-name :: <symbol>,
    required-init-keyword: name:;
end class <compiler-frontend>;

// <compiler-frontend-designator> -- exported
//
// The type of things that can name a particular frontend.
//
define constant <compiler-frontend-designator>
  = type-union(<symbol>, <compiler-frontend>);


// <compiler-backend> --exported
//
// The abstract superclass of all compiler backends.  Each backend
// should define a subtype of this class and implement the backend
// protocol.
//
define abstract open class <compiler-backend> (<object>)
  slot backend-name :: <symbol>,
    required-init-keyword: name:;
end class <compiler-backend>;

// <compiler-backend-designator> -- exported
//
// The type of things that can name a particular backend.
//
define constant <compiler-backend-designator>
  = type-union(<symbol>, <compiler-backend>);
