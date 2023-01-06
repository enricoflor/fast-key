fast-key.el

This package introduce the concept of "fast key repetion".  The
idea is to allow any keybinding to be sensitive to how fast it is
repeated.  This way you can have a certain key, say "<f7>" do one
thing if it's pressed once, and another if it is pressed twice fast
(and so on, you can have an arbitrary number of repetitions).

How fast you have to repeat it for it to be recognized as a fast
repetition depends on the value of the variable

  fast-key-seconds

whose default value is 0.3 (seconds).  Each definition of a fast
repetition command maps, minimally, a key to a set of commands,
which constitute the fast repetition cycle.  Every subsequent fast
repetition results in calling the next command in the list, and it
starts again from the car of the list once there have been more
fast repetitions than there are commands.  If you just keep the key
pressed, only the car of the list of command is repeatedly called
(this is the intended behavior: if it's not what you observe, you
may want to adjust the value of the variable
fast-key-minimum-time-separating-inputs).

To define a fast repetition command, use the macro fast-key-set.
It only has two obligatory arguments:

- key
- commands

KEY is a string that specifies the key: it must be a valid input to
the kbd macro.  COMMANDS is a list of functions.  Thus, fast
repetition of KEY will traverse the list of COMMANDS and call the
one whose index in the list corresponds to the number of fast
repetitions of KEY.  If you want arguments to be passed to the
commands you should wrap them in lambda expressions.

The macro fast-key-set also accepts 3 optional keyword arguments.

- :name   (a symbol), the name of the command KEY gets bound to.
          If nil, KEY will be bound to an unnamed function.

- :map    (a symbol of which keymapp is true) The keymap in which
          KEY gets bound.  If nil, it defaults to global-map

- :docstr (a string) The documentation string of the function KEY
          gets bound to.

This is a sample declaration:

  (fast-key-set "<f7>"
      '((lambda () (display-line-numbers-mode 'toggle))
        toggle-truncate-lines
        (lambda () (visual-line-mode 'toggle)))
    :name fast-key-sample
    :map text-mode-map
    :docstr
    "This is an example command to toggle line numbers, truncated
    lines and visual-line-mode.")
