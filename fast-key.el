;;; fast-key.el --- Interpret fast repeated input  -*- lexical-binding: t; -*-

;; Copyright (C) 2023 Enrico Flor

;; Author: Enrico Flor <enrico@eflor.net>
;; Maintainer: Enrico Flor <enrico@eflor.net>
;; Keywords: convenience

;; Package-Requires: ((emacs "26.1"))

;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see
;; <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This package introduce the concept of "fast key repetion".  The
;; idea is to allow any keybinding to be sensitive to how fast it is
;; repeated.  This way you can have a certain key, say "<f7>" do one
;; thing if it's pressed once, and another if it is pressed twice fast
;; (and so on, you can have an arbitrary number of repetitions).

;; How fast you have to repeat it for it to be recognized as a fast
;; repetition depends on the value of the variable

;;   fast-key-seconds

;; whose default value is 0.3 (seconds).  Each definition of a fast
;; repetition command maps, minimally, a key to a set of commands,
;; which constitute the fast repetition cycle.  Every subsequent fast
;; repetition results in calling the next command in the list, and it
;; starts again from the car of the list once there have been more
;; fast repetitions than there are commands.  If you just keep the key
;; pressed, only the car of the list of command is repeatedly called
;; (this is the intended behavior: if it's not what you observe, you
;; may want to adjust the value of the variable
;; fast-key-minimum-time-separating-inputs).

;; To define a fast repetition command, use the macro fast-key-set.
;; It only has two obligatory arguments:

;; - key
;; - commands

;; KEY is a string that specifies the key: it must be a valid input to
;; the kbd macro.  COMMANDS is a list of functions.  Thus, fast
;; repetition of KEY will traverse the list of COMMANDS and call the
;; one whose index in the list corresponds to the number of fast
;; repetitions of KEY.  If you want arguments to be passed to the
;; commands you should wrap them in lambda expressions.

;; The macro fast-key-set also accepts 3 optional keyword arguments.

;; - :name   (a symbol), the name of the command KEY gets bound to.
;;           If nil, KEY will be bound to an unnamed function.

;; - :map    (a symbol of which keymapp is true) The keymap in which
;;           KEY gets bound.  If nil, it defaults to global-map

;; - :docstr (a string) The documentation string of the function KEY
;;           gets bound to.

;; This is a sample declaration:

;;   (fast-key-set "<f7>"
;;       '((lambda () (display-line-numbers-mode 'toggle))
;;         toggle-truncate-lines
;;         (lambda () (visual-line-mode 'toggle)))
;;     :name fast-key-sample
;;     :map text-mode-map
;;     :docstr
;;     "This is an example command to toggle line numbers, truncated
;;     lines and visual-line-mode.")

;;; Code:

(require 'cl-lib)

(defgroup fast-key nil
  "Interpret fast repeated input."
  :prefix "fast-key-"
  :group 'convenience)

(defcustom fast-key-seconds 0.3
  "Maximum waiting time defining input repetition as fast.

The value of this variable is the amount of seconds that must not
elapse between two inputs for the two inputs to be considered a
\"fast repetition\" for the purposes of \\='fast-key\\='.

Set it to a higher value if you don't want to have to be too fast
in repeating the key.  Keep in mind, however, that the commands
bound to a key through `fast-key-set' will be called with the
delay specified by this variable."
  :type 'float)

(defcustom fast-key-minimum-time-separating-inputs 0.05
  "Minimum amount of seconds separating distinct inputs.

This is the amount of time X such that, if two inputs occur less
than X from one another, it will be assumed that the fingers were
not raised from the keyboard (that is, that is was a long key
press).

You should only change the value of this variable if keeping a
key K pressed (K having been bound to a list of commands through
`fast-key-set') results in the successive calling of all the
commands, instead of the repeated calling of the first command in
the list (which is the intended behaviour)."
  :type 'float)

(defvar fast-key--counter 0)

(defvar fast-key--timer nil)

(defvar fast-key--continuing nil)

(defvar fast-key--continuing-timer nil)

(defun fast-key--call (list-of-commands)
  "Evaluate one member of LIST-OF-COMMANDS.

LIST-OF-COMMANDS is a list of functions.

Which function in LIST-OF-COMMANDS is called depends on how many
times, and how fast repeatedly this function itself is evaluated.

Upon first evaluation, the car of LIST-OF-COMMANDS is set to be
called after the time specified by `fast-key-seconds'.  If this
function is evaluated again before that time expires, then the
second command in LIST-OF-COMMANDS is set to be called after
`fast-key-seconds' seconds, and so on.

The behavior is cyclic: if there are more fast repetitions than
there are commands in LIST-OF-COMMANDS, it starts from the car
again."
  (when (timerp fast-key--timer) (cancel-timer fast-key--timer))
  (when (or (> fast-key--counter (1- (length list-of-commands)))
            (not (eq last-command this-command)))
    (setq fast-key--counter 0))
  (if (and t fast-key--continuing)
      (funcall-interactively (nth 0 list-of-commands))
    (let* ((fn (nth fast-key--counter list-of-commands))
           (timed-fn `(lambda () (progn (setq fast-key--counter 0)
                                        (cancel-timer fast-key--timer)
                                        (funcall-interactively ',fn)))))
      (setq fast-key--continuing t
            fast-key--counter (1+ fast-key--counter)
            fast-key--timer (run-with-timer fast-key-seconds nil timed-fn))
      (setq fast-key--continuing-timer
            (run-with-timer fast-key-minimum-time-separating-inputs nil
                            (lambda () (setq fast-key--continuing nil)))))))

(cl-defmacro fast-key-set (key commands &key name map docstr)
  "Bind KEY to cyclic calling of COMMANDS.

KEY is a string that specifies a key or a key sequence, and must
be a valid input to the `kbd' macro.  COMMANDS is a list of
commands (that is functions, named or unnamed).

What is meant with \"cycling calling\" here is the following:
using this macro to set KEY to COMMANDS means that KEY, in
isolation, will call the first command in COMMANDS.  If KEY is
repeated faster than the time interval `fast-key-seconds', the
second command in COMMANDS is called.  In general, \"fast
repetitions\" of KEY will call the nth command in COMMANDS, where
n is the number of repetitions of KEY.

The keyword arguments NAME, MAP and DOCSTR are all optional:

  :name   (a symbol), the name of the command KEY gets bound to.
          If nil, KEY will be bound to an unnamed function.

  :map    (a symbol of which `keymapp' is true) The keymap in which
          KEY gets bound.  If nil, it defaults to `global-map'

  :docstr (a string) The documentation string of the function KEY
          gets bound to.

This is an example of a \\='fast-set-key\\=' declaration:

  (fast-key-set \"<f7>\"
      '((lambda () (display-line-numbers-mode 'toggle))
        toggle-truncate-lines
        (lambda () (visual-line-mode 'toggle)))
    :name fast-key-sample
    :map text-mode-map
    :docstr
    \"This is an example command to toggle line numbers, truncated
  lines and visual-line-mode.\")

With this declaration \"<f7>\" acquires this cyclic behavior in
buffers where it is looked up in `text-mode-map': if you press it
once, it toggles the display of line numbers, press it twice
quickly, it toggles the truncation of long lines, press it three
times quickly, it toggles `visual-line-mode'.  (If you press it
four times quickly, it toggles the display of line numbers.)

Note that the way to pass arguments to functions in
LIST-OF-COMMANDS is to write a lambda expression."
  (declare (indent 2) (debug t))
  (let* ((m (or map 'global-map))
         (ds (or docstr ""))
         (fn `(lambda nil ,ds (interactive) (fast-key--call ,commands))))
    (if (not name)
        `(define-key ,m (kbd ,key) ,fn)
      (fset name fn)
      `(define-key ,m (kbd ,key) ',name))))

(provide 'fast-key)

;;; _
;; Local Variables:
;; indent-tabs-mode: nil
;; End:

;;; fast-key.el ends here
