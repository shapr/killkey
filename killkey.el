;; stolen from https://www.emacswiki.org/emacs/KillKey
;; probably bsd3?
(defun diff-buffer-with-associated-file ()
  "View the differences between BUFFER and its associated file.
This requires the external program \"diff\" to be in your `exec-path'."
  (interactive)
  (let ((buf-filename buffer-file-name)
        (buffer (current-buffer)))
    (unless buf-filename
      (error "Buffer %s has no associated file" buffer))
    (let ((diff-buf (get-buffer-create
                     (concat "*Assoc file diff: "
                             (buffer-name)
                             "*"))))
      (with-current-buffer diff-buf
        (setq buffer-read-only nil)
        (erase-buffer))
      (let ((tempfile (make-temp-file "buffer-to-file-diff-")))
        (unwind-protect
            (progn
              (with-current-buffer buffer
                (write-region (point-min) (point-max) tempfile nil 'nomessage))
              (if (zerop
                   (apply #'call-process "diff" nil diff-buf nil
                          (append
                           (when (and (boundp 'ediff-custom-diff-options)
                                      (stringp ediff-custom-diff-options))
                             (list ediff-custom-diff-options))
                           (list buf-filename tempfile))))
                  (message "No differences found")
                (progn
                  (with-current-buffer diff-buf
                    (goto-char (point-min))
                    (if (fboundp 'diff-mode)
                        (diff-mode)
                      (fundamental-mode)))
                  (display-buffer diff-buf))))
          (when (file-exists-p tempfile)
            (delete-file tempfile)))))
      nil))

;; tidy up diffs when closing the file
(defun kill-associated-diff-buf ()
  (let ((buf (get-buffer (concat "*Assoc file diff: "
                             (buffer-name)
                             "*"))))
    (when (bufferp buf)
      (kill-buffer buf))))

(add-hook 'kill-buffer-hook 'kill-associated-diff-buf)

(global-set-key (kbd "C-c d") 'diff-buffer-with-associated-file)

(defun de-context-kill (arg)
  "Kill buffer, taking gnuclient into account."
  (interactive "p")
  (when (and (buffer-modified-p)
             buffer-file-name
             (not (string-match "\\*.*\\*" (buffer-name)))
             ;; erc buffers will be automatically saved
             (not (eq major-mode 'erc-mode))
             (= 1 arg))
    (when (file-exists-p buffer-file-name)
      (diff-buffer-with-associated-file))
    (error "Buffer has unsaved changes"))
  (if (and (boundp 'gnuserv-minor-mode)
             gnuserv-minor-mode)
      (gnuserv-edit)
    (set-buffer-modified-p nil)
    (kill-buffer (current-buffer))))

(global-set-key (kbd "C-x k") 'de-context-kill)

(provide 'killkey)
