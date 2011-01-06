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
end class <compiler-backend>;

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
// Sets the current compiler backend.
//
define function compiler-backend-setter
    (new-backend :: <compiler-backend>)
 => (new-backend :: <compiler-backend>);
  *backend* := new-backend;
end function compiler-backend-setter;

