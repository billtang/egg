;;; egg -- Emacs Got Git
;;; A magit fork

;; Copyright (C) 2008  Linh Dang
;; Copyright (C) 2008  Marius Vollmer
;;
;; Egg is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; Egg is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
;; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
;; License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary
;;;    This is my fork of Marius's excellent magit. his work is at:
;;;    http://zagadka.vm.bytemark.co.uk/magit
;;;

(require 'cl)
(require 'electric)

(defgroup egg nil
  "Controlling Git from Emacs."
  :prefix "egg-"
  :group 'tools)

(defface egg-header
  '((t :weight bold :inherit variable-pitch :height 1.3))
  "Face for generic headers.

Many Egg faces inherit from this one by default."
  :group 'egg)

(defface egg-text-base
  '((((class color) (background light))
     :foreground "navy" :inherit variable-pitch)
    (((class color) (background dark))
     :foreground "SteelBlue" :inherit variable-pitch)
    (t))
  "Face for description text."
  :group 'egg)

(defface egg-text-1
  '((t :inherit egg-text-base :height 1.2))
  "Face for description text."
  :group 'egg)

(defface egg-text-2
  '((t :inherit egg-text-base :height 1.3))
  "Face for description text."
  :group 'egg)

(defface egg-text-3
  '((t :inherit egg-text-base :height 1.5))
  "Face for description text."
  :group 'egg)

(defface egg-text-4
  '((t :inherit egg-text-base :height 1.8))
  "Face for description text."
  :group 'egg)

(defface egg-electrict-choice
  '((((class color) (background light))
     :foreground "Blue" :inherit egg-text-base :weight bold :height 1.2)
    (((class color) (background dark))
     :foreground "Cyan" :inherit egg-text-base  :weight bold :height 1.2)
    (t))
  "Face for description text."
  :group 'egg)


(defface egg-section-title
  '((((class color) (background light))
     :foreground "DarkGoldenrod" :inherit egg-header :height 1.1)
    (((class color) (background dark))
     :foreground "PaleGreen" :inherit egg-header :height 1.1)
    (t :weight bold))
  "Face for generic header lines.

Many Egg faces inherit from this one by default."
  :group 'egg)

(defface egg-branch
  '((((class color) (background light))
     :foreground "SkyBlue" :inherit egg-header :height 1.4)
    (((class color) (background dark))
     :foreground "Yellow" :inherit egg-header :height 1.4)
    (t :weight bold))
  "Face for the current branch."
  :group 'egg)

(defface egg-diff-file-header
  '((((class color) (background light))
     :foreground "SlateBlue" :inherit egg-header)
    (((class color) (background dark))
     :foreground "LightSlateBlue" :inherit egg-header)
    (t :weight bold))
  "Face for diff file headers."
  :group 'egg)

(defface egg-diff-hunk-header
  '((((class color) (background light))
     :background "grey85")
    (((class color) (background dark))
     :background "grey45"))
  "Face for diff hunk headers."
  :group 'egg)

(defface egg-diff-add
  '((((class color) (background light))
     :foreground "blue1")
    (((class color) (background dark))
     :foreground "white"))
  "Face for lines in a diff that have been added."
  :group 'egg)

(defface egg-diff-none
  '((((class color) (background light))
     :foreground "grey50")
    (((class color) (background dark))
     :foreground "grey70"))
  "Face for lines in a diff that are unchanged."
  :group 'egg)

(defface egg-diff-del
  '((((class color) (background light))
     :foreground "red")
    (((class color) (background dark))
     :foreground "OrangeRed"))
  "Face for lines in a diff that have been deleted."
  :group 'egg)

(defface egg-item-highlight
  '((((class color) (background light))
     :foreground "gray95")
    (((class color) (background dark))
     :foreground "gray30"))
  "Face for highlighting the current item."
  :group 'egg)

(defcustom egg-diff-init-hiding-mode nil
  "Initial hiding mode for diff results."
  :group 'egg
  :type '(choice :tag "Initial Hiding Mode"
		 (const :tag "Hide Nothing" nil)
		 (const :tag "Hide Everything" t)))

;;;========================================================
;;; simple routines
;;;========================================================
(defsubst egg-prepend (str prefix &rest other-properties)
  (propertize str 'display 
	      (apply 'propertize (concat prefix str) other-properties)))


(defun egg-cmd-to-string-1 (program args)
  "Execute PROGRAM and return its output as a string.
ARGS is a list of arguments to pass to PROGRAM."
  (let (str code)
    (setq str 
	  (with-output-to-string
	    (with-current-buffer
		standard-output
	      (setq code (apply 'call-process program nil t nil args)))))
    (if (= code 0)
	str
      nil)))

(defun egg-cmd-1 (program args)
  "Execute PROGRAM with ARGS.
The return code and the output are return as a cons."
  (let (str code)
    (setq str 
	  (with-output-to-string
	    (with-current-buffer
		standard-output
	      (setq code (apply 'call-process program nil t nil args)))))
    (cons code str)))

(defsubst egg-cmd-to-string (program &rest args)
  "Execute PROGRAM and return its output as a string.
ARGS is a list of arguments to pass to PROGRAM."
  (egg-cmd-to-string-1 program args))


(defun egg-git-to-string (&rest args)
  (let* ((str (egg-cmd-to-string-1 "git" args))
	 (len (length str)))
    (when (> len 0)
      (if (eq (aref str (1- len)) ?\n)
	  (substring str 0 -1)
	str))))

(defsubst egg-cmd-ok (program &rest args)
  (= (apply 'call-process program nil nil nil args) 0))

(defsubst egg-git-ok (&rest args)
  (= (apply 'call-process "git" nil nil nil args) 0))

(defsubst egg-wdir-clean () (egg-git-ok "diff" "--quiet"))
(defsubst egg-file-updated (file) 
  (egg-git-ok "diff" "--quiet" "--" file))
(defsubst egg-index-empty () (egg-git-ok "diff" "--cached" "--quiet"))

(defsubst egg-git-to-lines (&rest args)
  (split-string (substring (egg-cmd-to-string-1 "git" args) 0 -1)
		"\n"))

(defsubst egg-local-branches ()
  "Get a list of local branches. E.g. (\"master\", \"wip1\")."
  (egg-git-to-lines "rev-parse" "--symbolic" "--branches"))

(defun egg-remote-branches (&optional raw-p)
  "Get a list of remote branches. E.g. (\"origin/master\", \"joe/fork1\")."
  (let ((lst (egg-git-to-lines "rev-parse" "--symbolic" "--remotes")))
    (if raw-p lst
      (mapcar (lambda (full-name)
		(let ((tmp (split-string full-name "/")))
		  (cons (cadr tmp) (car tmp))))
	      lst))))

(defsubst egg-rbranch-to-remote (rbranch)
  (and (stringp rbranch)
       (> (length rbranch) 0)
       (car (split-string rbranch "/"))))

(defsubst egg-rbranch-name (rbranch)
  (and (stringp rbranch) 
       (> (length rbranch) 0)
       (cadr (split-string rbranch "/"))))

(defsubst egg-push-refspec (lbranch rbranch)
   (setq rbranch (egg-rbranch-name rbranch))
   (if (or lbranch rbranch)
       (format "%s%s%s" (or lbranch "") (if rbranch ":" "") (or rbranch ""))))

(defun egg-file-as-string-raw (file-name)
  (with-temp-buffer
    (insert-file-contents-literally file-name)
    (buffer-string)))

(defun egg-pick-file-contents (file-name regexp &rest indices)
  (with-temp-buffer
    (insert-file-contents-literally file-name)
    (goto-char (point-min))
    (when (re-search-forward regexp nil t)
      (if (null indices)
	  (match-string-no-properties 0)
	(dolist (idx indices)
	  (if (match-beginning idx)
	      (return (match-string-no-properties idx))))))))

(defun egg-pick-file-records (file-name start-re end-re)
  (with-temp-buffer
    (insert-file-contents-literally file-name)
    (goto-char (point-min))
    (let (lst beg)
      (save-match-data
	(while (re-search-forward start-re nil t)
	  (setq beg (match-beginning 0))
	  (when (re-search-forward end-re nil t)
	    (setq lst (cons (buffer-substring-no-properties 
			     beg (match-beginning 0))
			    lst)))))
      lst)))

(defun egg-file-as-string (file-name)
  (let ((str (egg-file-as-string-raw file-name)))
    (if (> (length str) 0)
	(substring str 0 -1)
      str)))

(defsubst egg-is-in-git ()
  (= (call-process "git" nil nil nil "rev-parse" "--git-dir") 0))

(defsubst egg-is-dir-in-git (dir)
  (let ((default-directory dir)) (egg-is-in-git)))

(defsubst egg-name-rev (rev)
  (egg-git-to-string "name-rev" "--always" "--name-only" rev))

(defun egg-read-git-dir ()
  (let ((dir (egg-git-to-string "rev-parse" "--git-dir")))
    (if (stringp dir) 
	(expand-file-name dir))))

(defsubst egg-read-dir-git-dir (dir)
  (let ((default-directory dir)) (egg-read-git-dir)))

(defvar egg-git-dir nil)
(defsubst egg-git-dir ()
  (if (local-variable-p 'egg-git-dir)
      egg-git-dir
    (set (make-local-variable 'egg-git-dir) (egg-read-git-dir))
    (set (intern (concat "egg-" egg-git-dir "-HEAD")) " Egg")
    egg-git-dir))

(defsubst egg-buf-git-dir (buffer)
  (with-current-buffer buffer
    (egg-git-dir)))

(defun egg-HEAD ()
  (let* ((git-dir (egg-git-dir))) 
    (if git-dir
	(egg-pick-file-contents (concat git-dir "/HEAD")
				 "^ref: refs/heads/\\(.+\\)\\|^\\([0-9a-z]+\\)" 1 2))))

(defun egg-all-refs (&optional raw-p)
  "Get a list of all refs."
  (append (egg-git-to-lines "rev-parse" "--symbolic"
			    "--branches" "--tags" "--remotes")
	  (delq nil
		(mapcar 
		 (lambda (head)
		   (if (file-exists-p (concat (egg-git-dir) "/" head))
		       head))
		 '("HEAD" "ORIG_HEAD" "MERGE_HEAD" "FETCH_HEAD")))))

(defsubst egg-current-branch ()
  (let* ((git-dir (egg-git-dir))
	 HEAD) 
    (when (stringp git-dir)
      (setq HEAD (egg-pick-file-contents (concat git-dir "/HEAD")
					 "^ref: refs/heads/\\(.+\\)" 1))
      (set (intern (concat "egg-" egg-git-dir "-HEAD"))
	   (format " Egg:%s" (or HEAD "(Detached)")))
      HEAD)))

(defsubst egg-current-sha1 ()
  (egg-git-to-string "rev-parse" "--verify" "-q" "HEAD"))

(defsubst egg-head ()
  (if (egg-git-dir)
      (cons (egg-current-sha1) (egg-current-branch))))

(defun egg-config-section-raw (type &optional name)
  (egg-pick-file-contents (concat (egg-git-dir) "/config")
			   (concat "^"
				   (if name (format "\\[%s \"%s\"\\]" type name)
				     (format "\\[%s\\]" type))
				   "\n"
				   "\\(\\(:?\t.+\n\\)+\\)")
			   1))

(defsubst egg-config-section (type &optional name)
  (mapcar 
   (lambda (line) (split-string line "[ =]+" t))
   (split-string (or (egg-config-section-raw type name) "")
		 "[\t\n]+" t)))

(defun egg-config-get-all (file type)
  (interactive "fFilename: ")
  (save-match-data
    (mapcar (lambda (rec)
	      (let ((key (car rec))
		    (infos (cdr rec)))
		(cons (progn (string-match "\"\\(.+\\)\"" key)
			     (match-string-no-properties 1 key))
		      (mapcar (lambda (attr)
				(split-string attr "[ =]+" t))
			      infos))))
	    (mapcar (lambda (str)
		      (split-string str "[\t\n]+" t))
		    (egg-pick-file-records file
					   (concat "^\\[" type " \"")
					   "^\\[")))))

(defsubst egg-config-get-all-branches ()
  (egg-config-get-all (concat (egg-git-dir) "/config") "branch"))

(defsubst egg-config-get (type attr &optional name)
  (and (egg-git-dir)
       (cadr (assoc attr (egg-config-section type name)))))

(defun egg-bool-config (type attr &optional name)
  (let ((flag (egg-config-get type attr name)))
    (cond ((equal flag "true")
	   t)
	  ((equal flag "false")
	   nil)
	  (t (error "Unexpected contents of boolean config %s of %s.%s"
		    attr type name)))))

(defun egg-tracking-target-wrong (branch)
  (dolist (rbranch-info (egg-config-get-all-branches))
    (let* ((infos (cdr rbranch-info))
	   (rbranch (car rbranch-info))
	   (lbranch (file-name-nondirectory (cadr (assoc "merge" infos))))
	   (remote (cadr (assoc "remote" infos))))
      (if (string= lbranch branch)
	  (return (concat remote "/" rbranch))))))

(defun egg-tracking-target (branch &optional mode)
  (let ((remote (egg-config-get "branch" "remote" branch))
	(rbranch (egg-config-get "branch" "merge" branch)))
    (when (stringp rbranch)
      (setq rbranch (file-name-nondirectory rbranch))
      (cond ((null mode) (concat remote "/" rbranch))
	    ((eq :name-only mode) rbranch)
	    (t (cons rbranch remote))))))


;;;========================================================
;;; Async Git process
;;;========================================================

(defun egg-async-do (exit-code func-args args)
  "Run GIT asynchronously with ARGS.
if EXIT code is an exit-code from GIT other than zero but considered
success."
  (let ((dir (file-name-directory (egg-git-dir)))
	(buf (get-buffer-create "*egg-process*"))
	(inhibit-read-only inhibit-read-only)
	(accepted-msg (and (integerp exit-code)
			   (format "exited abnormally with code %d"
				   exit-code)))
	proc)
    (setq proc (get-buffer-process buf))
    (when (and (processp proc) 		;; is a process
	       (not (eq (process-status proc) 'exit)) ;; not finised
	       (= (process-exit-status proc) 0))      ;; still running
      (error "EGG: %s is already running!" (process-command proc)))
    (with-current-buffer buf
      (setq inhibit-read-only t)
      (setq default-directory dir)
      ;;(erase-buffer)
      (widen)
      (goto-char (point-max))
      (insert "EGG-GIT-CMD:\n")
      (insert (format "%S\n" args))
      (insert "EGG-GIT-OUTPUT:\n")
      (setq proc (apply 'start-process "egg-git" buf "git" args))
      (setq mode-line-process " git")
      (when (and (consp func-args) (functionp (car func-args)))
	(process-put proc :callback-func (car func-args))
	(process-put proc :callback-args (cdr func-args)))
      (when (stringp accepted-msg)
	(process-put proc :accepted-msg accepted-msg)
	(process-put proc :accepted-code exit-code))
      (process-put proc :cmds (cons "git" args))
      (set-process-sentinel proc #'egg-process-sentinel))))

(defun egg-process-sentinel (proc msg)
  (let ((exit-code (process-get proc :accepted-code))
	(accepted-msg (process-get proc :accepted-msg))
	(callback-func (process-get proc :callback-func))
	(callback-args (process-get proc :callback-args))
	(cmds (process-get proc :cmds)))
    (cond ((string= msg "finished\n")
	   (message "EGG: git finished."))
	  ((string= msg "killed\n")
	   (message "EGG: git was killed."))
	  ((string-match accepted-msg msg)
	   (message "EGG: git exited with code: %d." exit-code))
	  ((string-match "exited abnormally" msg)
	   (message "EGG: git failed."))
	  (t (message "EGG: git is weird!")))
    (with-current-buffer (process-buffer proc)
      (setq mode-line-process nil)
      (widen)
      (goto-char (point-max))
      (re-search-backward "^EGG-GIT-CMD:" nil t)
      (narrow-to-region (point) (point-max))
      (if (functionp callback-func)
	  (apply callback-func proc cmds callback-args)))))


;;;========================================================
;;; Diff/Hunk
;;;========================================================

(defconst egg-section-map 
  (let ((map (make-sparse-keymap "Egg:Section")))
    (define-key map (kbd "h") 'egg-section-cmd-toggle-hide-show)
    (define-key map (kbd "H") 'egg-section-cmd-toggle-hide-show-children)
    (define-key map (kbd "n") 'egg-buffer-cmd-navigate-next)
    (define-key map (kbd "p") 'egg-buffer-cmd-navigate-prev)
    map))

(defconst egg-diff-section-map 
  (let ((map (make-sparse-keymap "Egg:Diff")))
    (set-keymap-parent map egg-section-map)
    (define-key map (kbd "RET") 'egg-diff-section-cmd-visit-file-other-window)
    (define-key map (kbd "o") 'egg-diff-section-cmd-visit-file)
    (define-key map (kbd "f") 'egg-diff-section-cmd-visit-file)
    map))

(defconst egg-staged-diff-section-map 
  (let ((map (make-sparse-keymap "Egg:Diff")))
    (set-keymap-parent map egg-diff-section-map)
    (define-key map (kbd "s") 'egg-diff-section-cmd-unstage)
    map))

(defconst egg-wdir-diff-section-map 
  (let ((map (make-sparse-keymap "Egg:Diff")))
    (set-keymap-parent map egg-diff-section-map)
    (define-key map (kbd "u") 'egg-diff-section-cmd-undo)
    map))

(defconst egg-unstaged-diff-section-map 
  (let ((map (make-sparse-keymap "Egg:Diff")))
    (set-keymap-parent map egg-wdir-diff-section-map)
    (define-key map (kbd "s") 'egg-diff-section-cmd-stage)
    map))

(defconst egg-hunk-section-map 
  (let ((map (make-sparse-keymap "Egg:Hunk")))
    (set-keymap-parent map egg-section-map)
    (define-key map (kbd "RET") 'egg-hunk-section-cmd-visit-file-other-window)
    (define-key map (kbd "o") 'egg-hunk-section-cmd-visit-file)
    (define-key map (kbd "f") 'egg-hunk-section-cmd-visit-file)
    map))

(defconst egg-staged-hunk-section-map 
  (let ((map (make-sparse-keymap "Egg:Hunk")))
    (set-keymap-parent map egg-hunk-section-map)
    (define-key map (kbd "s") 'egg-hunk-section-cmd-unstage)
    map))

(defconst egg-wdir-hunk-section-map 
  (let ((map (make-sparse-keymap "Egg:Hunk")))
    (set-keymap-parent map egg-hunk-section-map)
    (define-key map (kbd "u") 'egg-hunk-section-cmd-undo)
    map))

(defconst egg-unstaged-hunk-section-map 
  (let ((map (make-sparse-keymap "Egg:Hunk")))
    (set-keymap-parent map egg-wdir-hunk-section-map)
    (define-key map (kbd "s") 'egg-hunk-section-cmd-stage)
    map))

(defun list-tp ()
  (interactive)
  (message "tp: %S" (text-properties-at (point))))

(defun egg-safe-search (re limit &optional no)
  (save-excursion
    (save-match-data
      (and (re-search-forward re limit t)
	   (match-beginning (or no 0))))))

(defun egg-decorate-diff-header (no)
  (put-text-property (match-beginning 0)
		     (match-end 0)
		     'display
		     (propertize (concat "\n" (match-string-no-properties no))
				 'face
				 'egg-diff-file-header)))

(defun egg-decorate-diff-index-line (no)
  (put-text-property (1- (match-beginning 0))
		     (match-end 0)
		     'display
		     (propertize 
		      (concat "\t-- "
			      (match-string-no-properties no))
		      'face 'egg-diff-none)))

(defun egg-decorate-hunk-header (no)
  (put-text-property (match-beginning no)
		     (match-end no)
		     'face
		     'egg-diff-hunk-header)
  (put-text-property (match-end no)
		     (match-end 0)
		     'face
		     'egg-diff-none))

(defsubst egg-delimit-section (sect-type section beg end 
					  &optional inv-beg
					  keymap)
  (put-text-property beg end :sect-type sect-type)
  (put-text-property beg end sect-type section)
  (put-text-property beg end :navigation beg)
  (when (keymapp keymap)
    (put-text-property beg end 'keymap keymap))
  (when (integer-or-marker-p inv-beg) 
    (let ((current-inv (get-text-property inv-beg 'invisible)))
      (add-to-list 'current-inv beg t)
      (put-text-property inv-beg (1- end) 'invisible current-inv))))

(defun egg-decorate-diff-sequence (beg end diff-map hunk-map regexp
					diff-re-no
					hunk-re-no
					index-re-no
					del-re-no
					add-re-no
					none-re-no)
  (save-match-data
    (save-excursion
      (let (sub-beg sub-end head-end)
	(goto-char beg)
	(while (re-search-forward regexp end t)
	  (setq sub-beg (match-beginning 0))
	  (cond ((match-beginning del-re-no) ;; del
		 (put-text-property (match-beginning 0) (match-end 0)
				    'face 'egg-diff-del))
		((match-beginning add-re-no) ;; add
		 (put-text-property (match-beginning 0) (match-end 0)
				    'face 'egg-diff-add))
		((match-beginning none-re-no) ;; unchanged
		 (put-text-property (match-beginning 0) (match-end 0)
				    'face 'egg-diff-none))
		((match-beginning hunk-re-no) ;; hunk
		 (setq sub-end (or (egg-safe-search "^\\(:?diff\\|@@\\)" end)
				   end))
		 (egg-decorate-hunk-header hunk-re-no)
		 (egg-delimit-section 
		  :hunk (list (match-string-no-properties hunk-re-no) 
			      sub-beg sub-end)
		  sub-beg sub-end (match-end 0) hunk-map))
		((match-beginning diff-re-no) ;; diff
		 (setq sub-end (or (egg-safe-search "^diff " end) end))
		 (setq head-end (or (egg-safe-search "^@@" end) end))
		 (egg-decorate-diff-header diff-re-no)
		 (egg-delimit-section
		  :diff (list (match-string-no-properties diff-re-no)
			      sub-beg sub-end head-end)
		  sub-beg sub-end (match-end 0) diff-map))
		((match-beginning index-re-no) ;; index
		 (egg-decorate-diff-index-line index-re-no))
	      
		) ;; cond
	  )	  ;; while
	nil))))

(defun egg-decorate-diff-section (beg end &optional diff-src-prefix
				       diff-dst-prefix
				       diff-map hunk-map
				       a-rev b-rev)
  (let ((a (or diff-src-prefix "a/"))
	(b (or diff-dst-prefix "b/"))
	regexp)
    (when (stringp a-rev)
      (put-text-property beg end :a-revision a-rev))
    (when (stringp b-rev)
      (put-text-property beg end :b-revision b-rev))
    (setq regexp
	  (concat "^\\(?:"
		  "diff --git " a "\\(.+\\) " b ".+\\|" ;1 file
		  "\\(@@ .+@@\\).*\\|"			;2 hunk
		  "index \\(.+\\)\\|"			;3 index
		  "\\(-.*\\)\\|"			;4 del
		  "\\(\\+.*\\)\\|"			;5 add
		  "\\( .*\\)"				;6 none
		  "\\)$"))
    (egg-decorate-diff-sequence beg end diff-map hunk-map
				 regexp 1 2 3 4 5 6)))


(defun egg-diff-section-cmd-visit-file (file)
  (interactive (list (car (get-text-property (point) :diff))))
  (find-file file))

(defun egg-diff-section-cmd-visit-file-other-window (file)
  (interactive (list (car (get-text-property (point) :diff))))
  (find-file-other-window file))

(defun egg-hunk-compute-line-no (hunk-header hunk-beg)
  (let ((limit (line-end-position))
	(line (string-to-number (nth 2 (split-string hunk-header "[ @,\+,-]+" t))))
	(adjust 0))
    (save-excursion
      (goto-char hunk-beg)
      (forward-line 1)
      (end-of-line)
      (while (re-search-forward "^\\(:?\\+\\| \\).*" limit t)
	(setq adjust (1+ adjust))))
    (+ line adjust)))

(defun egg-hunk-section-cmd-visit-file (file hunk-header hunk-beg
					     &rest ignored)
  (interactive (cons (car (get-text-property (point) :diff))
		     (get-text-property (point) :hunk)))
  (let ((line (egg-hunk-compute-line-no hunk-header hunk-beg)))
    (find-file file)
    (goto-line line)))

(defun egg-hunk-section-cmd-visit-file-other-window (file hunk-header hunk-beg
							  &rest ignored)
  (interactive (cons (car (get-text-property (point) :diff))
		     (get-text-property (point) :hunk)))
  (let ((line (egg-hunk-compute-line-no hunk-header hunk-beg)))
    (find-file file)
    (goto-line line)))

(defun egg-section-cmd-toggle-hide-show (pos)
  (interactive (list (get-text-property (point) :navigation)))
  (if (assq pos buffer-invisibility-spec)
      (remove-from-invisibility-spec (cons pos t))
    (add-to-invisibility-spec (cons pos t)))
  (force-window-update (current-buffer)))

(defun egg-section-cmd-toggle-hide-show-children (pos sect-type)
  (interactive (list (get-text-property (point) :navigation)
		     (get-text-property (point) :sect-type)))

  (let ((end (next-single-property-change pos sect-type))
	child
	currently-hidden)
    (setq child (next-single-property-change pos :navigation nil end))
    (setq currently-hidden (and child
				(assq child buffer-invisibility-spec)))
    (setq child pos)
    (while (< (setq child (next-single-property-change child :navigation nil end)) end)
      (if currently-hidden
	  (remove-from-invisibility-spec (cons child  t))
	(add-to-invisibility-spec (cons child t))))
    (force-window-update (current-buffer))))

(defun egg-diff-section-patch-string (&optional pos)
  (let ((diff-info (get-text-property (or pos (point)) :diff)))
    (buffer-substring-no-properties (nth 1 diff-info)
				    (nth 2 diff-info))))

(defun egg-hunk-section-patch-string (&optional pos)
  (let ((diff-info (get-text-property (or pos (point)) :diff))
	(hunk-info (get-text-property (or pos (point)) :hunk)))
    (concat (buffer-substring-no-properties (nth 1 diff-info)
					    (nth 3 diff-info))
	    (buffer-substring-no-properties (nth 1 hunk-info)
					    (nth 2 hunk-info)))))

;;;========================================================
;;; Buffer
;;;========================================================
(defvar egg-buffer-refresh-func nil)

(defun egg-buffer-cmd-refresh ()
  (interactive)
  (when (and (egg-git-dir)
	     (functionp egg-buffer-refresh-func))
    (funcall egg-buffer-refresh-func (current-buffer))
    (recenter)))

(defun egg-buffer-cmd-navigate-next ()
  (interactive)
  (goto-char (or (next-single-property-change (point) :navigation)
		 (point))))

(defun egg-buffer-cmd-navigate-prev ()
  (interactive)
  (goto-char (previous-single-property-change (point) :navigation
					      nil (point-min))))

(defconst egg-buffer-mode-map
  (let ((map (make-sparse-keymap "Egg:Buffer")))
    (define-key map (kbd "q") 'quit-window)
    (define-key map (kbd "g") 'egg-buffer-cmd-refresh)
    (define-key map (kbd "n") 'egg-buffer-cmd-navigate-next)
    (define-key map (kbd "p") 'egg-buffer-cmd-navigate-prev)
    map))

(defun egg-get-buffer (fmt create-p)
  (let* ((git-dir (egg-git-dir))
	 (dir (file-name-directory git-dir))
	 (dir-name (file-name-nondirectory
		    (directory-file-name dir)))
	 (buf-name (format fmt dir-name git-dir))
	 (default-directory dir)
	 (buf (get-buffer buf-name)))
    (unless (or (bufferp buf) (not create-p))
      (setq buf (get-buffer-create buf-name)))
    buf))

(defmacro define-egg-buffer (type name-fmt &rest body)
  (let* ((type-name (symbol-name type))
	 (get-buffer-sym (intern (concat "egg-get-" type-name "-buffer")))
	 (buffer-mode-sym (intern (concat "egg-" type-name "-buffer-mode")))
	 (buffer-mode-hook-sym (intern (concat "egg-" type-name "-buffer-mode-hook")))
	 (buffer-mode-map-sym (intern (concat "egg-" type-name "-buffer-mode-map")))
	 (update-buffer-no-create-sym (intern (concat "egg-update-" type-name "-buffer-no-create"))))
    `(progn
       (defun ,buffer-mode-sym ()
	 ,@body)

       (defun ,get-buffer-sym (&optional create-p)
	 (let ((buf (egg-get-buffer ,name-fmt create-p)))
	   (when (bufferp buf)
	     (with-current-buffer buf
	       (unless (eq major-mode ',buffer-mode-sym)
		 (,buffer-mode-sym))))
	   buf))
       (defun ,update-buffer-no-create-sym ()
	 (let ((buf (,get-buffer-sym)))
	   (when (bufferp buf)
	     (with-current-buffer buf
	       (when (functionp egg-buffer-refresh-func)
		 (funcall egg-buffer-refresh-func buf))))))
       (add-hook 'egg-buffers-refresh-hook ',update-buffer-no-create-sym))))


;; (cl-macroexpand '(define-egg-buffer diff "*diff-%s@egg:%s*"))
;; (cl-macroexpand ' (define-egg-buffer diff (buf) "*diff-%s@egg:%s*" (show-diff buf) ))



;;;========================================================
;;; Status Buffer
;;;========================================================

(defun egg-sb-insert-repo-section ()
  (let ((head-info (egg-head))
	(beg (point)))
    (insert (propertize (or (cdr head-info) 
			    (format "Detached HEAD: %s"
				    (egg-name-rev (car head-info))))
			'face 'egg-branch) 
		"\n"
		(propertize (car head-info) 'face 'font-lock-string-face)
		"\n"
		(propertize (egg-git-dir) 'face 'font-lock-constant-face)
		"\n")
    (call-process "git" nil t nil
		  "log" "--max-count=5"
		  "--abbrev-commit" "--pretty=oneline")
    (egg-delimit-section :section 'repo beg (point))))

(defun egg-sb-insert-untracked-section ()
  (let ((beg (point)) inv-beg)
    (insert (egg-prepend "Untracked Files:" "\n\n" 
			  'face 'egg-section-title)
	    (progn (setq inv-beg (point))
		   "\n"))
    (call-process "git" nil t nil "ls-files" "--others" 
		  "--exclude-standard")
    (egg-delimit-section :section 'untracked beg (point)
			  inv-beg egg-section-map)))

(defun egg-sb-insert-unstaged-section (title &rest extra-diff-options)
  (let ((beg (point)) inv-beg)
    (insert (egg-prepend title "\n\n" 'face 'egg-section-title)
	    (progn (setq inv-beg (point))
		   "\n"))
    (apply 'call-process "git" nil t nil "diff" "--no-color"  "-p"
	   "--src-prefix=INDEX/" "--dst-prefix=WORKDIR/"
	   extra-diff-options)
    (egg-delimit-section :section 'unstaged beg (point)
			  inv-beg egg-section-map)
    (egg-decorate-diff-section beg (point) "INDEX/" "WORKDIR/"
				egg-unstaged-diff-section-map
				egg-unstaged-hunk-section-map)))

(defun egg-sb-insert-staged-section (title &rest extra-diff-options)
  (let ((beg (point)) inv-beg)
    (insert (egg-prepend title "\n\n"
			  'face 'egg-section-title)
	    (progn (setq inv-beg (point))
		   "\n"))
    (apply 'call-process "git" nil t nil "diff" "--no-color" "--cached" "-p"
	   "--src-prefix=HEAD/" "--dst-prefix=INDEX/"
	   extra-diff-options)
    (egg-delimit-section :section 'staged beg (point)
			  inv-beg egg-section-map)
    (egg-decorate-diff-section beg (point) "HEAD/" "INDEX/"
				egg-staged-diff-section-map
				egg-staged-hunk-section-map)))

(defconst egg-status-buffer-mode-map
  (let ((map (make-sparse-keymap "Egg:StatusBuffer")))
    (set-keymap-parent map egg-buffer-mode-map)
    (define-key map (kbd "c") 'egg-commit-log-edit)
    map))

(defun egg-status-buffer-redisplay (buf)
  (with-current-buffer buf
    (let ((inhibit-read-only t))
      (erase-buffer)
      (setq buffer-invisibility-spec nil)
      (egg-sb-insert-repo-section)
      (egg-sb-insert-unstaged-section "Unstaged Changes:")
      (egg-sb-insert-staged-section "Staged Changes:")
      (egg-sb-insert-untracked-section)
      (goto-char (point-min)))))

(define-egg-buffer status "*%s-status@%s*"
  "Major mode to display the egg status buffer."
  (kill-all-local-variables)
  (setq buffer-read-only t)
  (setq major-mode 'egg-status-buffer-mode
	mode-name  "Egg-Status"
	mode-line-process ""
	truncate-lines t)
  (use-local-map egg-status-buffer-mode-map)
  (set (make-local-variable 'egg-buffer-refresh-func)
       'egg-status-buffer-redisplay)
  (setq buffer-invisibility-spec nil)
  (run-mode-hooks 'egg-status-buffer-mode-hook))

(defun egg-status (&optional no-update-p)
  (interactive "P")
  (let ((buf (egg-get-status-buffer 'create)))
    (unless no-update-p
      (with-current-buffer buf
	(egg-status-buffer-redisplay buf)))
    (display-buffer buf t)))

;;;========================================================
;;; action
;;;========================================================

(defun egg-revert-visited-files (file-or-files)
  (let* ((git-dir (egg-git-dir))
	 (default-directory (file-name-directory git-dir))
	 (files (if (consp file-or-files) 
		   file-or-files
		 (list file-or-files))))
    (mapcar (lambda (file)
	      (let ((buf (get-file-buffer file)))
		(when (bufferp buf)
		  (with-current-buffer buf
		    (when (equal (egg-git-dir) git-dir)
		      (revert-buffer t t t))))))
	    files)))

(defun egg-revert-all-visited-files ()
  (let* ((git-dir (egg-git-dir))
	 (default-directory (file-name-directory git-dir))
	 bufs files)
    (setq files
	  (delq nil (mapcar (lambda (buf)
			      (with-current-buffer buf
				(when (and (buffer-file-name buf)
					   (equal (egg-git-dir) git-dir))
				  (buffer-file-name buf))))
			    (buffer-list))))
    (when (consp files)
      (setq files (mapcar 'expand-file-name
			  (apply 'egg-git-to-lines "ls-files" files)))
      (when (consp files)
	(egg-revert-visited-files files)))))

(defun egg-log-buffer ()
  (or (get-buffer (concat " *egg-logs@" (egg-git-dir) "*"))
      (let ((git-dir (egg-git-dir))
	    (default-directory default-directory)
	    dir)
	(unless git-dir
	  (error "Can't find git dir in %s" default-directory))
	(setq dir (file-name-nondirectory git-dir))
	(setq default-directory dir)
	(get-buffer-create (concat " *egg-logs@" git-dir "*")))))

(defsubst egg-log (&rest strings)
  (with-current-buffer (egg-log-buffer)
    (goto-char (point-max))
    (cons (current-buffer)
	  (prog1 (point)
	    (apply 'insert "LOG/" strings)))))

(defun egg-sync-handle-exit-code (ret accepted-codes logger)
  (let (output)
    (with-current-buffer (car logger)
      (save-excursion
	(goto-char (cdr logger))
	(forward-line 1)
	(setq output (buffer-substring-no-properties 
		      (point) (point-max)))))
    (egg-log (format "RET:%d\n" ret))
    (if (listp accepted-codes)
	(setq accepted-codes (cons 0 accepted-codes))
      (setq accepted-codes (list 0 accepted-codes)))
    (if (null (memq ret accepted-codes))
	(with-current-buffer (car logger)
	  (widen)
	  (narrow-to-region (cdr logger) (point-max))
	  (display-buffer (current-buffer) t)
	  nil)
      (run-hooks 'egg-buffers-refresh-hook)
      output)))

(defun egg-sync-do (program stdin accepted-codes args)
  (let (logger ret)
    (setq logger (egg-log "RUN:" program " " (mapconcat 'identity args " ")
			  (if stdin " <REGION\n" "\n")))
    (setq ret 
	  (cond ((stringp stdin)
		 (with-temp-buffer
		   (insert stdin)
		   (apply 'call-process-region (point-min) (point-max)
				program nil (car logger) nil args)))
		((consp stdin)
		 (apply 'call-process-region (car stdin) (cdr stdin)
			program nil (car logger) nil args))
		((null stdin)
		 (apply 'call-process program nil (car logger) nil args)))) 
    (egg-sync-handle-exit-code ret accepted-codes logger)))

(defsubst egg-sync-do-region-0 (program beg end args)
  (egg-sync-do program (cons beg end) nil args))

(defsubst egg-sync-do-region (program beg end &rest args)
  (egg-sync-do program (cons beg end) nil args))

(defsubst egg-sync-git-region (beg end &rest args)
  (egg-sync-do "git" (cons beg end) nil args))

(defun egg-sync-do-file (file program stdin accepted-codes args)
  (let ((default-directory (file-name-directory (egg-git-dir)))
	output)
    (setq file (expand-file-name file))
    (setq args (mapcar (lambda (word)
			 (if (string= word file) file word))
		       args))
    (when (setq output (egg-sync-do program stdin accepted-codes args))
      (cons file output))))

(defun egg-hunk-section-patch-cmd (pos program &rest args)
  (let ((patch (egg-hunk-section-patch-string pos))
	(file (car (get-text-property pos :diff))))
    (unless (stringp file)
      (error "No diff with file-name here!"))
    (egg-sync-do-file file program patch nil args)))

(defun egg-show-git-output (output line-no &optional prefix)
  (unless (stringp prefix) (setq prefix "GIT"))
  (if (consp output) (setq output (cdr output)))
  (when (and (stringp output) (> (length output) 1))
    (when (numberp line-no)
      (when (setq output (split-string output "\n" t))
	(cond ((< line-no 0)
	       (setq line-no (1+ line-no))
	       (setq output (nth line-no (nreverse output))))
	      ((> line-no 0)
	       (setq line-no (1- line-no))
	       (setq output (nth line-no output)))
	      (t (setq output nil)))))
    (when (stringp output)
      (message "%s> %s" prefix output))))

(defun egg-hunk-section-cmd-stage (pos)
  (interactive (list (point)))
  (egg-show-git-output 
   (egg-hunk-section-patch-cmd pos "git" "apply" "--cached")
   -1 "GIT-APPLY"))

(defun egg-hunk-section-cmd-unstage (pos)
  (interactive (list (point)))
  (egg-show-git-output 
   (egg-hunk-section-patch-cmd pos "git" "apply" "--cached" "--reverse")
   -1 "GIT-APPLY"))

(defun egg-hunk-section-cmd-undo (pos)
  (interactive (list (point)))
  (let ((file (egg-hunk-section-patch-cmd pos "patch"
					  "-p1" "--quiet" "--reverse")))
    (if (consp file) (setq file (car file)))
    (when (stringp file)
      (egg-revert-visited-files file))))

(defun egg-diff-section-patch-cmd (pos accepted-codes &rest args)
  (let ((file (car (get-text-property pos :diff))))
    (unless (stringp file)
      (error "No diff with file-name here!"))
    (egg-sync-do-file file "git" nil accepted-codes
		      (append args (list file)))))

(defun egg-diff-section-cmd-stage (pos)
  (interactive (list (point)))
  (egg-diff-section-patch-cmd pos nil "add"))

(defun egg-diff-section-cmd-unstage (pos)
  (interactive (list (point)))
  (egg-show-git-output 
   (egg-diff-section-patch-cmd pos 1 "reset" "HEAD" "--")
   1  "GIT-RESET"))

(defun egg-diff-section-cmd-undo-old-no-revsion-check (pos)
  (interactive (list (point)))
  (let ((file (egg-diff-section-patch-cmd pos nil "checkout" "--")))
    (if (consp file) (setq file (car file)))
    (when (stringp file)
      (egg-revert-visited-files file))))

(defun egg-diff-section-cmd-undo (pos)
  (interactive (list (point)))
  (let ((file (car (or (get-text-property pos :diff)
		       (error "No diff with file-name here!"))))
	(src-rev (get-text-property pos :a-revision))
	args)
    (setq args
	  (if (stringp src-rev)
	      (list "checkout" src-rev "--" file)
	    (list "checkout" "--" file)))
    (when (setq file (egg-sync-do-file file "git" nil nil args))
      (if (consp file) (setq file (car file)))
      (when (stringp file)
	(egg-revert-visited-files file)))))

(defun egg-file-stage-current-file ()
  (interactive)
  (let ((git-dir (egg-git-dir))
	(file (buffer-file-name)))
    (when (egg-sync-do-file file "git" nil nil (list "add" "--" file))
	(message "staged %s modifications" file))))

(defun egg-stage-all-files ()
  (interactive)
  (let* ((git-dir (egg-git-dir))
	 (default-directory (file-name-directory git-dir)))
    (when (egg-sync-do "git" nil nil (list "add" "-u"))
	(message "staged all tracked files's modifications"))))


;;;========================================================
;;; log message
;;;========================================================

(require 'derived)
(require 'ring)

(defvar egg-log-msg-ring (make-ring 32))
(defvar egg-log-msg-ring-idx nil)
(defvar egg-log-msg-action nil)
(defvar egg-log-msg-text-beg nil)
(defvar egg-log-msg-text-end nil)
(defvar egg-log-msg-diff-beg nil)
(define-derived-mode egg-log-msg-mode text-mode "Egg-LogMsg"
  "Major mode for editing Git log message.\n\n
\{egg-log-msg-mode-map}."
  (setq default-directory (file-name-directory (egg-git-dir)))
  (make-local-variable 'egg-log-msg-action)
  (set (make-local-variable 'egg-log-msg-ring-idx) nil)
  (set (make-local-variable 'egg-log-msg-text-beg) nil)
  (set (make-local-variable 'egg-log-msg-text-end) nil)
  (set (make-local-variable 'egg-log-msg-diff-beg) nil))

(define-key egg-log-msg-mode-map (kbd "C-c C-c") 'egg-log-msg-done)
(define-key egg-log-msg-mode-map (kbd "M-p") 'egg-log-msg-older-text)
(define-key egg-log-msg-mode-map (kbd "M-n") 'egg-log-msg-newer-text)
(define-key egg-log-msg-mode-map (kbd "C-l") 'egg-buffer-cmd-refresh)

(defun egg-log-msg-commit ()
  (let (output)
    (setq output 
	  (egg-sync-git-region egg-log-msg-text-beg egg-log-msg-text-end 
			       "commit" "-F" "-"))
    (when output
      (egg-show-git-output output -1 "GIT-COMMIT")
      (run-hooks 'egg-buffers-refresh-hook))))

(defun egg-log-msg-done ()
  (interactive)
  (widen)
  (goto-char egg-log-msg-text-beg)
  (if (save-excursion (re-search-forward "\\sw\\|\\-" 
					 egg-log-msg-text-end t))
      (when (functionp egg-log-msg-action)
	(ring-insert egg-log-msg-ring 
		     (buffer-substring-no-properties egg-log-msg-text-beg
						     egg-log-msg-text-end))
	(funcall egg-log-msg-action)
	(bury-buffer))
    (message "Please enter a log message!")
    (ding)))

(defun egg-log-msg-hist-cycle (&optional forward-p)
  "Cycle through message log history."
  (let ((len (ring-length egg-log-msg-ring)))
    (cond ((<= len 0) 
	   ;; no history
	   (message "No previous log message.")
	   (ding))
	  ;; don't accidentally throw away unsaved text
	  ((and  (null egg-log-msg-ring-idx)
		 (> egg-log-msg-text-end egg-log-msg-text-beg)
		 (not (y-or-n-p "throw away current text? "))))
	  ;; do it
	  (t (delete-region egg-log-msg-text-beg egg-log-msg-text-end)
	     (setq egg-log-msg-ring-idx
		   (if (null egg-log-msg-ring-idx)
		       (if forward-p 
			   ;; 1st-time + fwd = oldest
			   (ring-minus1 0 len)
			 ;; 1st-time + bwd = newest
		       0)
		     (if forward-p 
			 ;; newer
			 (ring-minus1 egg-log-msg-ring-idx len)
		       ;; older
		       (ring-plus1 egg-log-msg-ring-idx len)))) 
	     (goto-char egg-log-msg-text-beg)
	     (insert (ring-ref egg-log-msg-ring egg-log-msg-ring-idx))))))

(defun egg-log-msg-older-text ()
  "Cycle backward through comment history."
  (interactive)
  (egg-log-msg-hist-cycle))

(defun egg-log-msg-newer-text ()
  "Cycle forward through comment history."
  (interactive)
  (egg-log-msg-hist-cycle t))

(defun egg-commit-log-buffer-show-diffs (buf)
  (with-current-buffer buf
    (let ((inhibit-read-only t) beg)
      (goto-char egg-log-msg-diff-beg)
      (delete-region (point) (point-max))
      (setq beg (point))
      (egg-sb-insert-staged-section "Changes to Commit:" "--stat")
      (egg-sb-insert-unstaged-section "Deferred Changes:")
      (egg-sb-insert-untracked-section)
      (put-text-property beg (point) 'read-only t)
      (put-text-property beg (point) 'front-sticky nil)
      (force-window-update buf))))

(define-egg-buffer commit "*%s-commit@%s*"
  (egg-log-msg-mode)
  (setq major-mode 'egg-commit-buffer-mode
	mode-name "Egg-Commit"
	mode-line-process "")
  (set (make-local-variable 'egg-buffer-refresh-func)
       'egg-commit-log-buffer-show-diffs)
  (setq buffer-invisibility-spec nil)
  (run-mode-hooks 'egg-commit-buffer-mode-hook))

(defun egg-commit-log-edit ()
  (interactive)
  (let* ((git-dir (egg-git-dir))
	 (default-directory (file-name-directory git-dir))
	 (buf (egg-get-commit-buffer 'create))
	 (head-info (egg-head))
	 (head (or (cdr head-info) 
		   (format "Detached HEAD! (%s)" (car head-info))))
	 (inhibit-read-only inhibit-read-only))
    (pop-to-buffer buf)
    (setq inhibit-read-only t)
    (erase-buffer)
    (set (make-local-variable 'egg-log-msg-action) 'egg-log-msg-commit)
    (insert "Commiting into: " (propertize head 'face 'egg-branch) "\n"
	    "Repository: " (propertize git-dir 'face 'font-lock-constant-face) "\n"
	    (propertize "--------------- Commit Message (type C-c C-c when done) ---------------"
			'face 'font-lock-comment-face))
    (put-text-property (point-min) (point) 'read-only t)
    (put-text-property (point-min) (point) 'rear-sticky nil)
    (insert "\n")
    (set (make-local-variable 'egg-log-msg-text-beg) (point-marker))
    (set-marker-insertion-type egg-log-msg-text-beg nil)
    (put-text-property (1- egg-log-msg-text-beg) egg-log-msg-text-beg 
		       :navigation 'commit-log-text)
    (insert (propertize "\n------------------------ End of Commit Message ------------------------" 
			'read-only t 'front-sticky nil
			'face 'font-lock-comment-face))
    (set (make-local-variable 'egg-log-msg-diff-beg) (point-marker))
    (set-marker-insertion-type egg-log-msg-diff-beg nil)
    (egg-commit-log-buffer-show-diffs buf)
    (goto-char egg-log-msg-text-beg)
    (set (make-local-variable 'egg-log-msg-text-end) (point-marker))
    (set-marker-insertion-type egg-log-msg-text-end t)))

;;;========================================================
;;; diff-mode
;;;========================================================
(defvar egg-diff-buffer-info nil)

(defconst egg-diff-buffer-mode-map
  (let ((map (make-sparse-keymap "Egg:DiffBuffer")))
    (set-keymap-parent map egg-buffer-mode-map)
    map))

(defun egg-diff-buffer-insert-diffs (buffer)
  (with-current-buffer buffer
    (let ((args (plist-get egg-diff-buffer-info :args))
	  (title (plist-get egg-diff-buffer-info :title))
	  (prologue (plist-get egg-diff-buffer-info :prologue))
	  (src-prefix (plist-get egg-diff-buffer-info :src))
	  (dst-prefix (plist-get egg-diff-buffer-info :dst))
	  (src-rev (plist-get egg-diff-buffer-info :src-revision))
	  (dst-rev (plist-get egg-diff-buffer-info :dst-revision))
	  (diff-map (plist-get egg-diff-buffer-info :diff-map))
	  (hunk-map (plist-get egg-diff-buffer-info :hunk-map))
	  (inhibit-read-only t)
	  pos inv-beg)
      (erase-buffer)
      (insert (egg-prepend title "\n\n" 'face 'egg-section-title)
	      (progn (setq inv-beg (point))
		     "\n"))
      (insert prologue "\n")
      (apply 'call-process "git" nil t nil "diff" args)
      (egg-delimit-section :section 'top-level (point-min) (point))
      (egg-decorate-diff-section (point-min) (point)
				 src-prefix dst-prefix
				 diff-map hunk-map
				 src-rev dst-rev))))

(define-egg-buffer diff "*%s-diff@%s*"
  "Major mode to display the git diff output."
  (kill-all-local-variables)
  (setq buffer-read-only t)
  (setq major-mode 'egg-diff-buffer-mode
	mode-name  "Egg-Diff"
	mode-line-process ""
	truncate-lines t)
  (use-local-map egg-diff-buffer-mode-map)
  (set (make-local-variable 'egg-buffer-refresh-func)
       'egg-diff-buffer-insert-diffs)
  (setq buffer-invisibility-spec nil)
  (run-mode-hooks 'egg-diff-buffer-mode-hook))

(defun egg-do-diff (diff-info)
  (let* ((git-dir (egg-git-dir))
	 (dir (file-name-directory git-dir))
	 (buf (egg-get-diff-buffer 'create)))
    (with-current-buffer buf
      (set (make-local-variable 'egg-diff-buffer-info) diff-info)
      (egg-diff-buffer-insert-diffs buf))
    buf))

(defun egg-build-diff-info (src dst &optional file)
  (let* ((git-dir (egg-git-dir))
	 (dir (file-name-directory git-dir))
	 info tmp)
    (setq info
	  (cond ((and (null src) (null dst))
		 (list :args (list "--no-color" "-p"
				   "--src-prefix=INDEX/"
				   "--dst-prefix=WORKDIR/")
		       :title (format "from INDEX to %s" dir)
		       :prologue "hunks can be removed or added into INDEX."
		       :src "INDEX/" :dst "WORKDIR/"
		       :diff-map egg-unstaged-diff-section-map
		       :hunk-map egg-unstaged-hunk-section-map))
		((and (equal src "HEAD") (equal dst "INDEX"))
		 (list :args (list "--no-color" "--cached" "-p"
				   "--src-prefix=INDEX/"
				   "--dst-prefix=WORKDIR/")
		       :title "from HEAD to INDEX" 
		       :prologue "hunks can be removed from INDEX."
		       :src "HEAD/" :dst "INDEX/"
		       :diff-map egg-staged-diff-section-map
		       :hunk-map egg-staged-hunk-section-map))
		((and (stringp src) (stringp dst))
		 (list :args (list "--no-color" "-p"
				   (concat src ".." dst))
		       :title (format "from %s to %s" src dst) 
		       :prologue (format "a: %s\nb: %s" src dst)
		       :src-revision src
		       :dst-revision dst
		       :diff-map egg-diff-section-map
		       :hunk-map egg-hunk-section-map))
		((and (stringp src) (null dst))
		 (list :args (list "--no-color" "-p" src)
		       :title (format "from %s to %s" src dir) 
		       :prologue (concat (format "a: %s\nb: %s\n" src dir)
					 "hunks can be removed???")
		       :src-revision src
		       :diff-map egg-wdir-diff-section-map
		       :hunk-map egg-wdir-hunk-section-map))))
    (when (stringp file)
      (setq file (list file)))
    (when (consp file) 
      (setq tmp (plist-get info :prologue))
      (setq tmp (concat "\n"
			     (mapconcat 'identity file "\n")
			     "\n\n"
			     tmp))
      (plist-put info :prologue tmp)
      (setq tmp (plist-get info :args))
      (setq tmp (append tmp (cons "--" file)))
      (plist-put info :args tmp))
    info))


(defun egg-revs ()
  (apply 'nconc 
	 (mapcar (lambda (ref)
		   (cons ref 
			 (mapcar (lambda (suffix)
			     (concat ref suffix))
				 '("^" "^^" "^^^" "^^^^" "^^^^^"
				   "~0" "~1" "~2" "~3" "~4" "~5"))))
		 (egg-all-refs))))

(defun egg-read-rev (prompt &optional default special-rev)
  (unless (listp special-rev)
    (setq special-rev (list special-rev)))
  (completing-read prompt (nconc special-rev (egg-revs)) nil nil default))


;;;========================================================
;;; minor-mode
;;;========================================================
(defun egg-file-diff (&optional ask-p)
  "Diff the current file in another window."
  (interactive "P")
  (unless (buffer-file-name)
    (error "Current buffer has no associated file!"))
  (let ((git-file (egg-git-to-string "ls-files" "--full-name" "--" 
				     (buffer-file-name)))
	(src-rev (and ask-p (egg-read-rev "diff against: " "HEAD")))
	buf)
    (setq buf (egg-do-diff (egg-build-diff-info src-rev nil git-file))) 
    (pop-to-buffer buf)))

(defun egg-file-chekout-other-version (&optional confirm-p)
  "Checkout HEAD's version of the current file.
if CONFIRM-P was not null, then ask for confirmation if the
current file contains unstaged changes."
  (interactive)
  (unless (buffer-file-name)
    (error "Current buffer has no associated file!"))
  (let* ((file (buffer-file-name))
	 (file-modified-p (not (egg-file-updated (buffer-file-name))))
	 rev)
    (when file-modified-p
      (unless (y-or-n-p (format "ignored unstaged changes in %s? " file))
	(error "File %s contains unstaged changes!" file)))
    (setq rev (egg-read-rev (format "checkout %s version: " file) "HEAD"))
    (when (egg-sync-do-file file "git" nil nil (list "checkout" rev "--" file))
      (revert-buffer t t t))))

(defun egg-file-get-other-version (&optional rev prompt same-mode-p)
  (unless (buffer-file-name)
    (error "Current buffer has no associated file!"))
  (let* ((file (buffer-file-name))
	 (mode major-mode)
	 (git-dir (egg-git-dir))
	 (lbranch (egg-current-branch))
	 (rbranch (and git-dir (or (egg-tracking-target lbranch)
				   rev ":0")))
	 (prompt (or prompt (format "%s's version: " file)))
	 (rev (or rev (egg-read-rev prompt rbranch ":0")))
	 (canon-name (egg-git-to-string "ls-files" "--full-name" "--" 
					file))
	 (git-name (concat rev ":" canon-name))
	 (buf (get-buffer-create (concat "*" git-name "*"))))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
	(erase-buffer)
	(unless (= (call-process "git" nil buf nil "show" git-name)
		   0)
	  (error "Failed to get %s's version: %s" file rev))
	(when (and (functionp mode) same-mode-p)
	  (funcall mode))
	(set-buffer-modified-p nil)
	(setq buffer-read-only t)))
    buf))

(defun egg-file-version-other-window (&optional ask-p)
  "Show other version of the current file in another window."
  (interactive "P")
  (unless (buffer-file-name)
    (error "Current buffer has no associated file!"))
  (let ((buf (egg-file-get-other-version 
	      nil 
	      (format "show %s's version:" (buffer-file-name))
	      t)))
    (unless (bufferp buf)
      (error "Oops! can't get %s older version" (buffer-file-name)))
    (pop-to-buffer buf)))

(defun egg-file-ediff (&optional ask-for-dst-p)
  (interactive "P")
  (unless (buffer-file-name)
    (error "Current buffer has no associated file!"))
  (let* ((file buffer-file-name)
	 (dst-buf (if ask-for-dst-p
		      (egg-file-get-other-version 
		       nil
		       (format "(ediff) %s's newer version: " file)
		       t)
		    (current-buffer)))
	 (src-buf (egg-file-get-other-version 
		       nil
		       (format "(ediff) %s's older version: " file)
		       t)))
    (unless (and (bufferp dst-buf) (bufferp src-buf))
      (error "Ooops!"))
    (ediff-buffers dst-buf src-buf)))

(defconst egg-key-action-alist 
  '((?b :new-branch "start new [b]ranch" "Create and switch to a new branching starting from HEAD.")
    (?s :status "show repo's [s]tatus" "Browse the current status of the repo" )
    (?f :stage-file "stage current [f]ile" "Stage current file's changes")
    (?a :stage-all "stage [a]ll files" "Stage all current changes inside this repo.")
    (?d :diff-file "[d]iff current file" "Compare the current file against the staged snapshot.")
    (?c :commit "[c]ommit staged changes" "Process to commit current staged changes onto HEAD.")
    (?? :more-options "[?] more options" nil)
    (?q :quit "[q] quit" nil)))

(defconst egg-action-function-alist
  '((:new-branch . egg-checkout-new-branch)
    (:status     . egg-status)
    (:stage-file . egg-file-stage-current-file)
    (:stage-all  . egg-stage-all-files)
    (:diff-file  . egg-file-diff)
    (:commit     . egg-commit-log-edit)
    (:quit 	 . (lambda () (message "do nothing now! later.") (ding) nil))))

(defcustom egg-next-action-prompt-p t
  "Always prompt when trying to guess the next logical action ."
  :group 'egg
  :type 'boolean)

(defconst egg-electrict-select-action-buffer 
  (get-buffer-create "*Egg:Select Action*"))

(defun egg-select-action-run ()
  (interactive)
  (let (action)
    (save-excursion
      (with-current-buffer egg-electrict-select-action-buffer
	(beginning-of-line)
	(when (boundp 'egg-electric-in-progress-p)
	  (setq action (get-text-property (point) :action))
	  (if action
	      (throw 'egg-select-action action)
	    (ding)))))))

(defun egg-select-action-quit ()
  (interactive)
  (let (action)
    (save-excursion
      (with-current-buffer egg-electrict-select-action-buffer 
	(beginning-of-line)
	(when (boundp 'egg-electric-in-progress-p)
	  (throw 'egg-select-action nil))))))

(defconst egg-electric-select-action-map 
  (let ((map (make-sparse-keymap "Egg:SelectAction")))
    (define-key map "q" 'egg-select-action-quit)
    (define-key map (kbd "RET") 'egg-select-action-run)
    (define-key map (kbd "SPC") 'egg-select-action-run)
    (define-key map (kbd "C-l") 'recenter)
    map))

(defun egg-electric-select-action (default desc)
  (let ((egg-electric-in-progress-p t)
	(old-buffer (current-buffer))
	(buf egg-electrict-select-action-buffer)
	(action-alist
	 (delq nil (mapcar (lambda (entry)
			     (if (cadddr entry)
				 (cons (cadr entry)
				       (cadddr entry))))
			   egg-key-action-alist)))
	action default-entry beg)
    (setq default-entry (assq default action-alist))
    (setq action-alist
	  (cons default-entry (remq default-entry action-alist)))
    (unwind-protect
	(setq action
	      (catch 'egg-select-action
		(save-window-excursion
		  (with-current-buffer buf
		    (let ((inhibit-read-only t))
		      (erase-buffer)
		      (insert (propertize "Select Action\n" 'face
					  'egg-section-title))
		      (insert (propertize desc 'face 'egg-text-1) "\n\n")
		      (insert (propertize "select an action:" 
					  'face 'egg-text-1)
			      "\n\n")
		      (put-text-property (point-min) (point)
					 'intangible t)
		      (setq beg (point))
		      (insert 
		       (mapconcat
			(lambda (entry)
			  (propertize (concat "- " (cdr entry))
				      :action (car entry)
				      'face 'egg-electrict-choice))
			action-alist
			"\n")
		       "\n")
		      (goto-char beg)
		      (set-buffer-modified-p nil) 
		      (setq buffer-read-only t))
		    (setq major-mode 'egg-select-action)
		    (setq mode-name "Egg-Select")
		    (use-local-map egg-electric-select-action-map)) 
		  (Electric-pop-up-window egg-electrict-select-action-buffer)
		  (goto-char beg)
		  (Electric-command-loop 'egg-select-action
					 "select next action> "))))
      (bury-buffer buf))
    (when (and action (symbolp action))
      action)))

(defun egg-guess-next-action (file-is-modified-p
			      wdir-is-modified-p
			      index-is-clean)
  (if file-is-modified-p
      :stage-file 
    ;; file is unchanged
    (if wdir-is-modified-p
	:stage-all
      ;; wdir is clean
      (if index-is-clean
	  :new-branch
	:commit))))

(defun egg-build-key-prompt (prefix default alternatives)
  (let ((action-desc-alist (mapcar 'cdr egg-key-action-alist)))
    (concat prefix " default: "
	    (nth 1 (assq default action-desc-alist))
	  ". alternatives:  "
	  (mapconcat 'identity 
		     (mapcar (lambda (action)
			       (nth 1 (assq action action-desc-alist)))
			     (remq default alternatives)) ", "))))

(defun egg-prompt-next-action (file-modified-p
			       wdir-modified-p
			       index-clean-p)
  (let ((default (egg-guess-next-action file-modified-p
					wdir-modified-p
					index-clean-p))
	desc key action alternatives)
    (setq alternatives (list default :status :more-options))
    (while (null action)
      (setq key (read-key-sequence 
		 (egg-build-key-prompt "next action?"
				       default alternatives)))
      (setq key (string-to-char key))
      (setq action 
	    (if  (memq key '(?\r ?\n ?\ ))
		default 
	      (cadr (assq key egg-key-action-alist))))
      (when (eq action :more-options)
	(setq desc
	      (format "%s %s\n%s %s\nINDEX %s"
		      (buffer-file-name)
		      (if file-modified-p 
			  "contains unstaged changes"
			"is not modified")
		      (file-name-directory (egg-git-dir))
		      (if wdir-modified-p
			  "contains unstaged changes"
			"has no unstaged changes")
		      (if index-clean-p "is identical to HEAD"
			"contains staged changes to commit")))
	(setq action (egg-electric-select-action default desc)))
      (when (null action)
	(ding)))
    action))

(defun egg-next-action (&optional ask-p)
  (interactive "P")
  (save-some-buffers nil 'egg-is-in-git)
  (let ((file-modified-p (not (egg-file-updated (buffer-file-name))))
	(wdir-modified-p (not (egg-wdir-clean)))
	(index-clean-p (egg-index-empty))
	action default)
     (setq action (if (or ask-p egg-next-action-prompt-p)
		      (egg-prompt-next-action file-modified-p
					      wdir-modified-p
					      index-clean-p)
		    (egg-guess-next-action file-modified-p
					   wdir-modified-p
					   index-clean-p)))
     
     (funcall (cdr (assq action egg-action-function-alist)))))

(defvar egg-minor-mode nil)
(defvar egg-minor-mode-map (make-sparse-keymap "Egg"))
(defvar egg-file-cmd-map (make-sparse-keymap "Egg:File"))

(defun egg-mode-key-prefix-set (var val)
  (define-key egg-minor-mode-map (read-kbd-macro val) egg-file-cmd-map)
  (custom-set-default var val))

(let ((map egg-file-cmd-map))
  (define-key map (kbd "a") 'egg-blame)
  (define-key map (kbd "b") 'egg-checkout-new-branch)
  (define-key map (kbd "d") 'egg-status)
  (define-key map (kbd "c") 'egg-commit-log-edit)
  (define-key map (kbd "i") 'egg-file-stage-current-file)
  (define-key map (kbd "l") 'egg-show-logs)
  (define-key map (kbd "o") 'egg-file-chekout-other-version)
  (define-key map (kbd "s") 'egg-status)
  (define-key map (kbd "u") 'egg-cancel-modifications)
  (define-key map (kbd "v") 'egg-next-action)
  (define-key map (kbd "w") 'egg-commit-log-edit)
  (define-key map (kbd "=") 'egg-file-diff)
  (define-key map (kbd "~") 'egg-file-version-other-window))

(defcustom egg-mode-key-prefix "C-x v"
  "Prefix keystrokes for egg minor-mode commands."
  :group 'egg
  :type 'string
  :set 'egg-mode-key-prefix-set)

;;;###autoload
(defun egg-minor-mode (&optional arg)
  "Turn-on egg-minor-mode which would enable key bindings for
egg in current buffer."
  (interactive "p")
  (setq egg-minor-mode (if (null arg)
			     (not egg-minor-mode)
			   (> arg 0)))
  (when egg-minor-mode
    (if (boundp 'vc-mode)
	(set 'vc-mode nil))
    (make-local-variable 'egg-minor-mode-name) 
    (setq egg-minor-mode-name 
	  (intern (concat "egg-" (egg-git-dir) "-HEAD")))))

;;;###autoload
(defun egg-minor-mode-find-file-hook ()
  (when (egg-is-in-git)
    (make-local-variable 'egg-minor-mode)
    (egg-minor-mode 1)))

(defvar egg-minor-mode-name " Egg")

(or (assq 'egg-minor-mode minor-mode-alist)
    (setq minor-mode-alist
	  (cons '(egg-minor-mode egg-minor-mode-name) minor-mode-alist)))

(setcdr (or (assq 'egg-minor-mode minor-mode-map-alist)
	    (car (setq minor-mode-map-alist
		       (cons (list 'egg-minor-mode)
			     minor-mode-map-alist))))
	egg-minor-mode-map)

(if (and (boundp 'vc-handled-backends)
	 (listp (symbol-value 'vc-handled-backends)))
    (set 'vc-handled-backends
	 (delq 'Git (symbol-value 'vc-handled-backends))))

(add-hook 'find-file-hook 'egg-git-dir)
(add-hook 'find-file-hook 'egg-minor-mode-find-file-hook)

(provide 'egg)
