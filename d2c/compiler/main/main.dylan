module: main
copyright: see below

//======================================================================
//
// Copyright (c) 1995, 1996, 1997  Carnegie Mellon University
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


//----------------------------------------------------------------------
// Where to find various important files.
//----------------------------------------------------------------------

// $default-dylan-dir and $default-target-name are defined in
// file-locations.dylan, which is generated by Makegen.

// If DYLANDIR is defined, then it is assumed to be the root of the install
// area, and the location of platforms.descr and the libraries are derived from
// there.  Otherwise we use the autoconf prefix @prefix@.  It would be nice to
// use libdir, etc., but the default substitutions contain ${prefix}
// variables, which Dylan doesn't have yet.

define constant $dylan-dir = getenv("DYLANDIR") | $default-dylan-dir;
define constant $dylan-user-dir = getenv("DYLANUSERDIR") | getenv("DYLANDIR") | $default-dylan-user-dir;

// Platform parameter database.
define constant $default-targets-dot-descr
  = concatenate($dylan-dir, "/share/dylan/platforms.descr");

// Library search path.

// Location of runtime.h
define constant $runtime-include-dir
  = concatenate($dylan-dir, "/include");

define class <interactive-debugger> (<debugger>)
end class <interactive-debugger>;

define method invoke-debugger
    (debugger :: <interactive-debugger>, condition :: <condition>)
    => res :: <never-returns>;
  fresh-line(*debug-output*);
  format(*debug-output*, "%s\n", condition);
  force-output(*debug-output*);
  make(<command>, name: "Break", summary: "Break out of command processor.",
       command: method(x) invoke-debugger(*old-debugger*, condition) end);
  run-command-processor();
  call-out("abort", void:);
end;
  
define variable *old-debugger* = *debugger*;

//----------------------------------------------------------------------
// Main
//----------------------------------------------------------------------

define method main (argv0 :: <byte-string>, #rest args) => ();
  c-decl("extern int GC_expand_hp(size_t number_of_bytes);");
  unless (getenv("D2C_SMALL_MACHINE"))
    c-expr(void: "GC_expand_hp(384*1024*1024)");
  end;

  *random-state* := make(<random-state>, seed: 0);

  // Set up our argument parser with a description of the available options.
  let argp = make(<argument-list-parser>);
  set-up-argument-list-parser(argp); 

  // Parse our command-line arguments.
  unless(parse-arguments(argp, args))
    show-usage-and-exit();
  end unless;

  // Handle our informational options.
  if (option-value-by-long-name(argp, "help"))
    show-help(*standard-output*);
    exit(exit-code: 0);
  end if;
  if (option-value-by-long-name(argp, "version"))
    show-copyright(*standard-output*);
    exit(exit-code: 0);
  end if;
  
  // Get our simple options.
  let target-machine-name = option-value-by-long-name(argp, "target") | $default-target-name;
  let target-machine =  as(<symbol>, target-machine-name);
  let library-dirs = option-value-by-long-name(argp, "libdir");
  let features = option-value-by-long-name(argp, "define");
  let log-dependencies = option-value-by-long-name(argp, "log-deps");
  let log-text-du = option-value-by-long-name(argp, "dump-du");
  let no-binaries-pre = option-value-by-long-name(argp, "no-binaries");
  let no-makefile = option-value-by-long-name(argp, "no-makefile");
  let no-binaries = no-binaries-pre | no-makefile;
  let cc-override = option-value-by-long-name(argp, "cc-override-command");
  let override-files = option-value-by-long-name(argp, "cc-override-file");
  let link-static = option-value-by-long-name(argp, "static");

  let link-rpath = option-value-by-long-name(argp, "rpath")
       | format-to-string("%s/lib/dylan/%s/%s/dylan-user",
			  $dylan-user-dir,
			  $version, target-machine-name);

  *break-on-compiler-errors* = option-value-by-long-name(argp, "break");
  let debug? = option-value-by-long-name(argp, "debug");
  let profile? = option-value-by-long-name(argp, "profile");
  *emit-all-function-objects?* = debug?;

  // For folks who have *way* too much time (or a d2c bug) on their hands.
  let debug-optimizer = option-value-by-long-name(argp, "debug-optimizer");

  if(debug-optimizer)
    debug-optimizer := string-to-integer(debug-optimizer);
  else
    debug-optimizer := 0;
  end if;

  if(option-value-by-long-name(argp, "debug-compiler"))
       *debugger* := make(<interactive-debugger>);
  end if;

  let dump-testworks-spec? = option-value-by-long-name(argp, "testworks-spec");

  // Determine our compilation target.
  let targets-file = option-value-by-long-name(argp, "platforms") |
    $default-targets-dot-descr;

  // Decide if anyone passed some '-o' flags to our optimizer.
  let optimizer-options = option-value-by-long-name(argp, "optimizer-option");
  let optimizer-option-table = make(<table>);
  for (option :: <string> in optimizer-options)
    let (key, value) =
      if (option.size > 3 & copy-sequence(option, end: 3) = "no-")
	values(copy-sequence(option, start: 3), #f);
      else
	values(option, #t);
      end;
    optimizer-option-table[as(<symbol>, key)] := value;
  end for;

  // How many threads are we using
  let thread-count = option-value-by-long-name(argp, "thread-count");
  if(thread-count)
    thread-count := string-to-integer(thread-count);
  else
    thread-count := #f;
  end if;

  // Figure out which optimizer to use.
  let optimizer-class =
    if (element(optimizer-option-table, #"null", default: #f))
      format(*standard-error*,
	     "d2c: warning: -onull produces incorrect code\n");
      <null-optimizer>;
    else
      <cmu-optimizer>;
    end;
  *current-optimizer* := make(optimizer-class,
			      options: optimizer-option-table,
			      debug-optimizer: debug-optimizer);

  // Set up our target.
  if (targets-file == #f)
    error("Can't find platforms.descr");
  end if;
  parse-platforms-file(as(<file-locator>, targets-file));
  *current-target* := get-platform-named(target-machine);

  define-platform-constants(*current-target*);
  define-bootstrap-module();

  // Stuff in DYLANPATH goes after any explicitly listed directories.
  let dylanpath = getenv("DYLANPATH");
  let dirs = if(dylanpath)
               split-at(method (x :: <character>);
                          x == $search-path-seperator;
                        end,
                        dylanpath);
             else
               list(".", 
                    concatenate($dylan-user-dir, "/lib/dylan/", $version, 
                                "/", target-machine-name, "/dylan-user"),
                    concatenate($dylan-dir, "/lib/dylan/", $version, "/", 
                                target-machine-name));
             end;
  for (dir in dirs)
    push-last(library-dirs, dir);
  end for;
  		       
  *Data-Unit-Search-Path*
       := map-as(<simple-object-vector>,
                 curry(as, <directory-locator>),
                 library-dirs);

  if (option-value-by-long-name(argp, "compiler-info"))
    show-compiler-info(*standard-output*);
    exit(exit-code: 0);
  end if;
  if (option-value-by-long-name(argp, "dylan-user-location"))
    show-dylan-user-location(*standard-output*);
    exit(exit-code: 0);
  end if;
  if (option-value-by-long-name(argp, "optimizer-sanity-check"))
    enable-sanity-checks();
  end if;

  let args = regular-arguments(argp);

  local method build-file(locator :: <file-locator>)
          let state
            = if(locator.locator-extension = "dylan")
                format(*standard-output*, "Entering single file mode.\n");
                force-output(*standard-output*);
                make(<single-file-mode-state>,
                     source-locator: locator,
                     command-line-features: as(<list>, features), 
                     log-dependencies: log-dependencies,
                     log-text-du: log-text-du,
                     target: *current-target*,
                     no-binaries: no-binaries,
                     no-makefile: no-makefile,
                     link-static: link-static,
                     link-rpath: link-rpath,
                     debug?: debug?,
                     profile?: profile?);
              else
                make(<lid-mode-state>,
                     lid-locator: locator,
                     command-line-features: as(<list>, features), 
                     log-dependencies: log-dependencies,
                     log-text-du: log-text-du,
                     target: *current-target*,
                     no-binaries: no-binaries,
                     no-makefile: no-makefile,
                     link-static: link-static,
                     link-rpath: link-rpath,
                     debug?: debug?,
                     profile?: profile?,
                     dump-testworks-spec?: dump-testworks-spec?,
                     cc-override: cc-override,
                     override-files: as(<list>, override-files),
                     thread-count: thread-count);
              end if;
          compile-library(state);
        end method build-file;

  if (option-value-by-long-name(argp, "interactive")
        | args.size = 0)
    make(<command>, name: "Build",
         summary: "Build specified library.",
         command: method(filename)
                      let locator = as(<file-locator>, filename);
                      build-file(locator);
                  end);
    run-command-processor();
    exit();
  end if;

  // Process our regular arguments
  unless (args.size = 1)
    show-usage-and-exit();
  end unless;

  let lid-locator = as(<file-locator>, args[0]);

  let worked? = build-file(lid-locator);
  exit(exit-code: if (worked?) 0 else 1 end);
end method main;
