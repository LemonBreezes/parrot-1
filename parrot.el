;;; parrot.el --- Party Parrot rotates gracefully in mode-line.  -*- lexical-binding: t; -*-

;; Author: Daniel Ting <deep.paren.12@gmail.com>
;; URL: https://github.com/dp12/parrot.git
;; Version: 1.1.1
;; Package-Requires: ((emacs "24.1"))
;; Keywords: party, parrot, rotate, sirocco, kakapo, games

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; A minor mode for displaying party parrot in the modeline and rotating words.
;;
;; To load this file, add (require 'parrot) to your init file.  You can display
;; the party parrot in your modeline by adding (parrot-mode).
;;
;; To get the parrot to rotate on new email messages in mu4e, add:
;; (add-hook 'mu4e-index-updated-hook #'parrot-start-animation)
;;
;; This animation code is a heavily modified version of Jacek "TeMPOraL"
;; Zlydach's famous nyan-mode.  Check out his original work at
;; https://github.com/TeMPOraL/nyan-mode/.
;;
;; Please see README.md for more documentation, or read it online at
;; https://github.com/dp12/parrot

;;; Code:

(require 'parrot-rotate)
(require 'parrot-progress)

(defconst parrot-directory (file-name-directory (or load-file-name buffer-file-name)))
(defconst parrot-modeline-help-string "mouse-1: Rotate with parrot!")

;; ('v') (*'v') ('V'*) ('v'*)
;; ('v') ('V') ('>') ('^') ('<') ('V') ('v')

;; Internal variables
(defvar parrot--animation-timer nil
  "Internal timer used for switching animation frames.")
(defvar parrot--rotations 0
  "Counter of how many times the parrot has rotated.")
(defvar parrot--old-cdr-mode-line-position nil
  "Used to store anything we clobber in the `mode-line-position'.")
(defvar parrot--visible nil
  "Controls `parrot--create' output.
If you are a `doom-modeline' user, see `doom-modeline-segment--parrot'")
(defvar parrot--animation-frames nil
  "A list of the animation frames for the current parrot.")
(defvar parrot--current-frame 0)
(defvar parrot--frame-list (number-sequence 1 10)  ;; TODO this is a bit oddly named and also initialized wrong.
  "List of indices for the parrot animation frames.
For example, an animation with a total of ten frames would have a
`parrot-frame-list` of (1 2 3 4 5 6 7 8 9 10)")
(defvar parrot--static-image nil
  "The image shown when parrot is at rest, i.e. not rotating.")

;; Internal functions
(defun parrot--sequence-length (parrot)
  "Return length of the animation sequence for PARROT."
  (cond ((string= parrot "default") 10)
        ((string= parrot "confused") 26)
        ((string= parrot "emacs") 10)
        ((string= parrot "nyan") 10)
        ((string= parrot "rotating") 13)
        ((string= parrot "science") 10)
        ((string= parrot "thumbsup") 12)
        (t (error (format "Invalid parrot %s" parrot)))))

(defun parrot--create-frame (parrot id)
  "Create image for frame with parrot type PARROT and frame id ID."
  (create-image (concat parrot-directory
                        (format "img/%s/%s-parrot-frame-%d.xpm" parrot parrot id)) 'xpm nil :ascent 'center))

(defun parrot--load-frames (parrot)
  "Load the images for the selected PARROT."
  (setq parrot--frame-list (number-sequence 1 (parrot--sequence-length parrot)))
  (when (image-type-available-p 'xpm)
    (setq parrot--static-image (parrot--create-frame parrot 1))
    (setq parrot--animation-frames (mapcar (lambda (id)
                                            (parrot--create-frame parrot id))
                                          parrot--frame-list))))

(defun parrot--refresh (&optional maybe-static)
  "Show the results of updated options.

MAYBE-STATIC is appropriate for changes that do not affect
animation and cannot be better demonstrated with animation.  This
is also affected by `parrot-animate'.  If the parrot only shows
during animation, then it will animate to show the update.

This refresh will enable the mode if necessary to provide user
feedback, which could also animate depending on settings."
  (when (featurep 'parrot)
    (if (not parrot-mode)
        (parrot-mode 1)
      (parrot--load-frames parrot-type))
    (if (or (and maybe-static (eq parrot-animate 'hide-static))
            (not maybe-static))
        (parrot-start-animation)
      (force-mode-line-update))))

(defun parrot--show-parrot ()
  "Add parrot to the modeline.
If you are a `doom-modeline' user, see
`doom-modeline-segment--parrot'.  Doom performs some overrides,
using `parrot-create' directly whenever `parrot-mode' is active."
  (unless parrot--visible
    (progn
      (unless parrot--old-cdr-mode-line-position
        (setq parrot--old-cdr-mode-line-position (cdr mode-line-position))
        (setcdr mode-line-position (cons '(:eval (list (parrot--create)))
                                         (cdr parrot--old-cdr-mode-line-position))))
      (setf parrot--visible t)
      (force-mode-line-update))))

(defun parrot--remove-parrot ()
  "Remove parrot from modeline."
  (when parrot--visible
    (progn
      (setcdr mode-line-position parrot--old-cdr-mode-line-position)
      (setf parrot--old-cdr-mode-line-position nil)
      (setf parrot--visible nil)
      (force-mode-line-update))))

(defun parrot--switch-anim-frame ()
  "Change to the next frame in the parrot animation.
If the parrot has already rotated for `parrot-num-rotations', the animation will
stop."
  (setq parrot--current-frame (% (+ 1 parrot--current-frame) (car (last parrot--frame-list))))
  (when (eq parrot--current-frame 0)
    (unless (eq -1 parrot--rotations)
      (setq parrot--rotations (+ 1 parrot--rotations)))
    (when (and parrot-num-rotations (>= parrot--rotations parrot-num-rotations))
      (parrot-stop-animation)))
  (force-mode-line-update))

(defun parrot--get-anim-frame ()
  "Get the current animation frame."
  (if (not (memq parrot-animate '(no-animation)))
      (nth parrot--current-frame parrot--animation-frames)
    parrot--static-image))

(defun parrot--add-click-handler (string)
  "Add a handler to STRING for animating the parrot when it is clicked."
  (propertize string 'keymap `(keymap (mode-line keymap (down-mouse-1 . ,(lambda () (interactive)
                                                                           (parrot-start-animation)
                                                                           (run-hooks 'parrot-click-hook)))))))

(defun parrot--create ()
  "Generate the party parrot string."
  (if (or (not parrot--visible)
          (< (window-width) parrot-minimum-window-width))
      ""                                ; disabled for too small windows
    (let ((parrot-string (make-string parrot-spaces-before ?\s)))
      (setq parrot-string (concat parrot-string (parrot--add-click-handler
                                                 (propertize "-" 'display (parrot--get-anim-frame)))
                                  (make-string parrot-spaces-after ?\s)))
      (propertize parrot-string 'help-echo parrot-modeline-help-string))))

(defalias 'parrot-create 'parrot--create
  "For `doom-modeline-segment--parrot' and other custom modelines
that want to control the position of the parrot.")

;; customize group
(defgroup parrot nil
  "Customization group for `parrot-mode'."
  :group 'frames)

(defcustom parrot-animation-frame-interval 0.045
  "Number of seconds between animation frames."
  :group 'parrot
  :type 'float
  :set (lambda (sym val)
         (set-default sym val)
         (parrot--refresh)))

(defcustom parrot-click-hook nil
  "Hook run after clicking on the parrot."
  :group 'parrot
  :type 'hook
  :set (lambda (sym val)
         (set-default sym val)
         (parrot--refresh t)))

(defcustom parrot-minimum-window-width 45
  "Determines the minimum width of the window, below which party parrot will not be displayed."
  :group 'parrot
  :type 'integer
  :set (lambda (sym val)
         (set-default sym val)
         (parrot--refresh t)))

(defcustom parrot-spaces-before 0
  "Spaces of padding before parrot in mode line."
  :group 'parrot
  :type 'integer
  :set (lambda (sym val)
         (set-default sym val)
         (parrot--refresh t)))

(defcustom parrot-spaces-after 0
  "Spaces of padding after parrot in the mode line."
  :type 'integer
  :group 'parrot
  :set (lambda (sym val)
         (set-default sym val)
         (parrot--refresh t)))

(defcustom parrot-num-rotations 3
  "How many times party parrot will rotate."
  :group 'parrot
  :type 'integer
  :set (lambda (sym val)
         (set-default sym val)
         (parrot--refresh)))

(defcustom parrot-animate 'animate
  "Animation and show/hide preference.
Possible values: non-nil or 'animate to always show the parrot,
animating or not.  `'no-animation' to show the parrot but never
animate it.  `'hide-static' to only show the parrot when not
animating.

nil will rever to the legacy `parrot-animate-parrot' no animation
behavior, the same as `'no-animation'."
  :group 'parrot
  :type '(choice (const :tag "Always show" animate)
                 (const :tag "No animation" no-animation)
                 (const :tag "Hide when not animating" hide-static))
  :set (lambda (sym val)
         ;; map legacy nil value to 'no-animation
         ;; map legacy t value to 'animate
         (let* ((val (if (eq val nil) 'no-animation val))
                (val (if (eq val t) 'animation val)))
           (set-default sym val)
           (parrot--refresh))))

(defcustom parrot-animate-on-load nil
  "If non-nil animate when `parrot-mode' enabled."
  :group 'parrot
  :type 'boolean
  :set (lambda (sym val)
               (set-default sym val)
               (parrot--refresh)))

(defcustom parrot-type 'default
  "What kind of parrot, such as default or nyan.
Also see `parrot-set-parrot-type'."
  :group 'parrot
  :type '(choice (const :tag "Default" default)
                 (const :tag "Confused" confused)
                 (const :tag "Emacs" emacs)
                 (const :tag "Nyan Cat" nyan)
                 (const :tag "Rotating" rotating)
                 (const :tag "Science" science)
                 (const :tag "Thumbsup" thumbsup))
  :set (lambda (sym val)
         (set-default sym val)
         (parrot--refresh)))

;; user commands

;;;###autoload
(defun parrot-start-animation (&optional persist force-animation)
  "Start the parrot animation.
PERSIST will set `parrot--rotations' to -1 and cause infinite
animation until `parrot-stop-animation' is called.

FORCE-ANIMATION is a non-interactive way to ignore `parrot-animate'

When called interactively, this function does not respect
`parrot-animate' and will always animate."
  (interactive)
  (let* ((user (called-interactively-p 'interactive))
         (animate (or user
                      (not (eq parrot-animate 'no-animation))
                      force-animation)))

    ;; In any case where loading the mode starts an animation, this call is
    ;; idempotent with the mode
    (when (not (bound-and-true-p parrot-mode))
      (parrot-mode))
    (parrot--show-parrot) ;; also idempotent over `parrot--visible'
    (unless (eq parrot--rotations -1)
      (setq parrot--rotations (if persist -1 0)))
    (when animate
      (when (not parrot--animation-timer)
        (setq parrot--animation-timer (run-at-time nil
                                                   parrot-animation-frame-interval
                                                   #'parrot--switch-anim-frame))))))

(defun parrot-stop-animation ()
  "Stop the parrot animation.
If a persistent animation is being broken, animation will
continue for `parrot-num-roatiations'"
  (interactive)
  (if (eq parrot--rotations -1)
      (setq parrot--rotations 0)
    (when parrot--animation-timer
      (cancel-timer parrot--animation-timer)
      (setq parrot--animation-timer nil)
      (setq parrot--rotations 0))
    (when (eq parrot-animate 'hide-static)
      (parrot--remove-parrot))))

(defun parrot-set-parrot-type (parrot &optional silent)
  "Set the desired PARROT type in the mode line.
SILENT will not show the parrot even if settings enable it."
  (interactive
   (list
    (completing-read "Select parrot: "
                     ;; TODO use the customize options list
                     '(default confused emacs nyan rotating science thumbsup) nil t)))
  (if silent
      (prog1
          (setq parrot-type parrot)
        (parrot--load-frames parrot-type))
    (custom-set-variables `(parrot-type ,parrot))))

;;;###autoload
(define-minor-mode parrot-mode
  "Use Parrot to show when you're rotating.
You can customize this minor mode, see `customize-group' `parrot'."
  :global t
  :require 'parrot
  (if parrot-mode
      (progn
        (parrot--load-frames parrot-type)
        (if parrot-animate-on-load
            (parrot-start-animation nil t)
          (if (memq parrot-animate '(animate no-animation))
            (parrot--show-parrot)))
        (parrot--maybe-add-todo-hook)
        (parrot--maybe-advise-magit-push))
    (progn
      (parrot-stop-animation)
      (parrot--remove-parrot)
      (parrot--maybe-add-todo-hook)
      (parrot--maybe-advise-magit-push))))

(provide 'parrot)

;;; parrot.el ends here
