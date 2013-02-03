;;; enotify-spectator.el --- Enotify plugin for spectator-emacs (ruby TDD)

;; Copyright (C) 2012  Alessandro Piras

;; Author: Alessandro Piras <laynor@gmail.com>
;; Keywords: convenience
;; URL: http://www.github.com/laynor/spectator-emacs

;; This file is part of spectator-emacs.

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

;; This enotify plugin is meant to be used together with the
;; spectator-emacs ruby gem.
;;
;; Installation: add this file to your load path and require it:
;; (add-to-list 'load-path "path/to/enotify-spectator/")
;; (require 'enotify-spectator)
;;
;; This plugin can take advantage of alert.el. If you want to enable
;; alert.el alerts, customize `enotify-spectator-use-alert' and ensure
;; alert.el is loaded before this file.

;;; Code:

(require 'enotify)

(defgroup enotify-spectator nil
  "Enotify plugin for spectator-emacs"
  :group 'enotify)

(defcustom enotify-spectator-use-alert nil
  "whether enotify-spectator should use alert.el"
  :group 'enotify-spectator
  :type 'boolean)

(defcustom enotify-spectator-alert-severity 'trivial
  "severity for alert.el alerts"
  :group 'enotify-spectator
  :type '(choice (const :tag "Urgent" urgent)
		 (const :tag "High" high)
		 (const :tag "Moderate" moderate)
		 (const :tag "Normal" normal)
		 (const :tag "Low" low)
		 (const :tag "Trivial" trivial)))

(defcustom enotify-spectator-alert-use-separate-log-buffers nil
  "whether enotify-spectator should use different alert log
buffers for each project."
  :group 'enotify-spectator
  :type 'boolean)


(defcustom enotify-spectator-change-face-timeout nil
  "amount of seconds after which the notification face should be changed."
  :group 'enotify-spectator
  :type '(choice (const nil) integer))

(defcustom enotify-spectator-timeout-face :standard
  "face to apply to the notification text on timeout"
  :group 'enotify-spectator
  :type '(choice (const :tag "Standard enotify face" :standard )
		 (const :tag "Standard enotify success face" :success)
		 (const :tag "Standard enotify warning face" :warning)
		 (const :tag "Standard enotify failure face" :failure)
		 face))

(defcustom enotify-rspec-handler 'enotify-rspec-handler
  "Message handler for enotify spectator-emacs notifications.
This function should take 2 arguments, (id data), where id is the
enotify slot id, and data contains the rspec output.
The default handler just writes the results in a buffer in org-mode.")

(defvar enotify-rspec-result-message-handler 'enotify-rspec-result-message-handler
  "Don't touch me - used by spectator-emacs.")

(defvar enotify-rspec-mouse-1-handler 'enotify-rspec-mouse-1-handler
  "Mouse-1 handler function. It takes an event parameter. See enotify README for details.")

(defcustom spectator-get-project-root-dir-function 'rinari-root
  "Function used to get ruby project root."
  :group 'enotify-spectator)

(defcustom spectator-test-server-cmd "spork"
  "Test server command - change this to bundle exec spork if you are using bundle.
Change to nil if you don't want to use any test server."
  :group 'enotify-spectator)

(defcustom spectator-watchr-cmd "spectator-emacs"
  "Command to run watchr - change this to bundle exec watchr if you are using bundle."
  :group 'enotify-spectator)



;;;; Alert.el stuff

(when (featurep 'alert)
  (defun enotify-spectator-alert-id (info)
    (car (plist-get info :data)))
  (defun enotify-spectator-alert-face (info)
    (enotify-face (cdr (plist-get info :data))))

  (defun enotify-spectator-chomp (str)
    "Chomp leading and tailing whitespace from STR."
    (while (string-match "\\`\n+\\|^\\s-+\\|\\s-+$\\|\n+\\'"
			 str)
      (setq str (replace-match "" t t str)))
    str)

  (defun* enotify-spectator-colorized-summary (info &optional (with-timestamp t))
    (let* ((s+t (plist-get info :message))
	   (summary (if with-timestamp s+t (car (last (split-string s+t ":"))))))
      (enotify-spectator-chomp
       (propertize summary 'face (enotify-spectator-alert-face info)))))

  (defun enotify-spectator-alert-log (info)
    (let ((bname (format "*Alerts - Spectator-emacs [%s]*" (enotify-spectator-alert-id info))))
      (with-current-buffer
	  (get-buffer-create bname)
	(goto-char (point-max))
	(insert (format-time-string "%H:%M %p - ")
		(enotify-spectator-colorized-summary info nil)
		?\n))))

  (defun alert-spectator-notify (info)
    "alert.el notifier function for enotify-spectator."
    (when enotify-spectator-alert-use-separate-log-buffers
      (enotify-spectator-alert-log info))
    (message "%s: %s"
	     (alert-colorize-message (format "Enotify - spectator-emacs [%s]:"
					     (enotify-spectator-alert-id info))
				     (plist-get info :severity))
	     (enotify-spectator-colorized-summary info)))

  ;;; enotify-spectator alert style
  (alert-define-style 'enotify-spectator
		      :title "Display message in minibuffer for enotify-spectator alerts"
		      :notifier #'alert-spectator-notify
		      :remover #'alert-message-remove)

  (defun enotify-spectator-summary (id)
    "Extract summary from enotify notifiations sent by spectator-emacs."
    (let* ((notification (enotify-mode-line-notification id))
	   (help-text (plist-get notification :help))
	   (face (enotify-face (plist-get notification :face)))
	   (summary-text (nth 1 (split-string help-text "\n"))))
      summary-text))


  (defun enotify-spectator-face (id)
    "Extracts the face used for the enotify notification sent by spectator-emacs"
    (enotify-face (plist-get (enotify-mode-line-notification id) :face)))

  ;;; Use enotify-spectator style for all the alerts whose category is enotify-spectator
  (alert-add-rule :predicate (lambda (info)
			       (eq (plist-get info :category)
				   'enotify-spectator))
		  :style 'enotify-spectator))


;;;; Enotify stuff

(defun enotify-rspec-result-buffer-name (id)
  (format "*RSpec Results: %s*" id))

(defun enotify-rspec-handler (id data)
  (let ((buf (get-buffer-create (enotify-rspec-result-buffer-name id))))
    (save-current-buffer
      (set-buffer buf)
      (erase-buffer)
      (insert data)
      (flet ((message (&rest args) (apply 'format args)))
	(org-mode)))))

(defun enotify-rspec-result-message-handler (id data)
  (when enotify-spectator-change-face-timeout
    (run-with-timer enotify-spectator-change-face-timeout nil
		    'enotify-change-notification-face
		    id enotify-spectator-timeout-face))
  (when (and enotify-spectator-use-alert (featurep 'alert))
    (let ((alert-log-messages (if enotify-spectator-alert-use-separate-log-buffers
				  nil
				alert-log-messages)))
      (alert (enotify-spectator-summary id)
	     :title id
	     :data (cons id (enotify-spectator-face id))
	     :category 'enotify-spectator
	     :severity enotify-spectator-alert-severity)))
  (funcall enotify-rspec-handler id data))

(defun enotify-rspec-mouse-1-handler (event)
  (interactive "e")
  (switch-to-buffer-other-window
   (enotify-rspec-result-buffer-name
    (enotify-event->slot-id event))))


;;;; Rinari / spectator-emacs stuff
(defvar spectator-script " # -*-ruby-*-
require 'rspec-rails-watchr-emacs'
@specs_watchr ||= Rspec::Rails::Watchr.new(self,
                                           ## uncomment the line below if you are using RspecOrgFormatter
                                           # :error_count_line => -6,
                                           ## uncomment to customize the notification messages that appear on the notification area
                                           # :notification_message => {:failure => 'F', :success => 'S', :pending => 'P'},
                                           ## uncomment to customize the message faces (underscores are changed to dashes)
                                           # :notification_face => {
                                           #   :failure => :my_failure_face, #will be `my-failure-face' on emacs
                                           #   :success => :my_success_face,
                                           #   :pending => :my_pending_face},
                                           ## uncomment for custom matcher!
                                           # :custom_matcher => lambda { |path, specs| puts 'Please fill me!' }
                                           ## uncomment for custom summary extraction
                                           # :custom_extract_summary_proc => lambda { |results| puts 'Please Fill me!' }
                                           ## uncomment for custom enotify slot id (defaults to the base directory name of
                                           ## your application rendered in CamelCase
                                           # :slot_id => 'My slot id'
                                           )
")


(defun spectator-generate-script ()
  "Creates a spectator-emacs script in the project root directory"
  (let ((dir (funcall spectator-get-project-root-dir-function)))
    (when dir
      (with-temp-file (concat dir "/.spectator")
	(insert spectator-script)))))

(defun spectator-script ()
  (interactive)
  (find-file (concat (funcall spectator-get-project-root-dir-function) "/.spectator")))

(defun spectator-run-in-shell (cmd &optional dir bufname)
  (let* ((default-directory (or dir default-directory))
	 (shproc (shell bufname)))
    (comint-send-string shproc (concat cmd "\n"))))

(defun spectator-app-name ()
  (let ((root-dir (funcall spectator-get-project-root-dir-function)))
    (when root-dir
      (apply 'concat
	     (mapcar 'capitalize
		     (split-string (file-name-nondirectory
				    (directory-file-name
				     root-dir))
				   "[^a-zA-Z0-9]"))))))

(defun spectator ()
  (interactive)
  (let ((project-root (funcall spectator-get-project-root-dir-function))
	(app-name (spectator-app-name)))
    (spectator-run-in-shell spectator-test-server-cmd
			     project-root
			     (concat "*Spork - " app-name  "*"))
    (spectator-run-in-shell (concat spectator-watchr-cmd " .spectator")
			     project-root
			     (concat "*Spectator - " app-name  "*"))))

;;; Some utilities

(defun spectator-find-spectator-1 (pattern)
  (let ((bnames  (mapcar 'buffer-name (buffer-list)))
	(app-name (spectator-app-name)))
    (when app-name
      (find-if (lambda (el) (string-match (format "%s.*%s" pattern app-name) el))
	       bnames))))
(defun spectator-maybe-switch-to-buffer (buf &optional msg)
  (if buf
    (switch-to-buffer buf)
    (message "Could not open buffer. %s" (or msg  "Did you run spectator? Try M-x spectator RET."))))

(defun spectator-find-spectator ()
  (interactive)
  (spectator-maybe-switch-to-buffer (spectator-find-spectator-1 "*Spectator")))

(defun spectator-find-spectator-results ()
  (interactive)
  (spectator-maybe-switch-to-buffer (spectator-find-spectator-1 "*RSpec Results")
				     "Either spectator is not running or no tests have been executed yet."))

(defun spectator-find-spectator-spork ()
  (interactive)
  (spectator-maybe-switch-to-buffer (spectator-find-spectator-1 "*Spork")))

(provide 'enotify-spectator)

;;; enotify-spectator.el ends here
