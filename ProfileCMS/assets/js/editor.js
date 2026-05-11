'use strict';

// ── Article editor (editor.php) ──────────────────────────────────────────
const editorEl = document.getElementById('quill-editor');
if (editorEl) {
    const quill = new Quill('#quill-editor', {
        theme: 'snow',
        modules: {
            toolbar: [
                [{ header: [1, 2, 3, false] }],
                ['bold', 'italic', 'underline', 'strike'],
                ['blockquote', 'code-block'],
                [{ list: 'ordered' }, { list: 'bullet' }],
                [{ indent: '-1' }, { indent: '+1' }],
                ['link', 'image'],
                ['clean'],
            ],
        },
        placeholder: 'Write something…',
    });

    // On submit: copy Quill HTML into the hidden input
    const form = document.getElementById('editor-form');
    if (form) {
        form.addEventListener('submit', () => {
            document.getElementById('content-input').value = quill.root.innerHTML;
        });
    }
}

// ── CV editor (settings.php) ─────────────────────────────────────────────
const cvEditorEl = document.getElementById('cv-quill-editor');
if (cvEditorEl) {
    const cvQuill = new Quill('#cv-quill-editor', {
        theme: 'snow',
        modules: {
            toolbar: [
                [{ header: [1, 2, 3, false] }],
                ['bold', 'italic', 'underline'],
                [{ list: 'ordered' }, { list: 'bullet' }],
                ['link'],
                ['clean'],
            ],
        },
    });

    const settingsForm = document.getElementById('settings-form');
    if (settingsForm) {
        settingsForm.addEventListener('submit', () => {
            document.getElementById('cv-content-input').value = cvQuill.root.innerHTML;
        });
    }
}
