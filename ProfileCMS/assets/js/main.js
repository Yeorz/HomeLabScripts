'use strict';

// Mobile nav toggle
const toggle = document.querySelector('.nav-toggle');
const navLinks = document.querySelector('.nav-links');
if (toggle && navLinks) {
    toggle.addEventListener('click', () => navLinks.classList.toggle('open'));
}

// Auto-generate slug from title (public-facing: not needed, but shared here for admin)
function toSlug(str) {
    return str.toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

// Admin: wire title → slug auto-fill
const titleInput = document.getElementById('title');
const slugInput  = document.getElementById('slug-input');
if (titleInput && slugInput) {
    let userEditedSlug = slugInput.value !== '';
    slugInput.addEventListener('input', () => { userEditedSlug = true; });
    titleInput.addEventListener('input', () => {
        if (!userEditedSlug) slugInput.value = toSlug(titleInput.value);
    });
}
