/* ============================================
   CHRISTIAN BWENDO — PORTFOLIO SCRIPT
   ============================================ */

'use strict';

// =====================
// LOADER
// =====================
window.addEventListener('load', () => {
  setTimeout(() => {
    const loader = document.getElementById('loader');
    if (loader) {
      loader.classList.add('hidden');
      // Trigger hero animations after loader
      document.querySelectorAll('.animate-in').forEach(el => {
        el.classList.add('loaded');
      });
      // Start counter animations
      startCounters();
    }
  }, 2000);
});

// =====================
// CUSTOM CURSOR
// =====================
const cursorGlow = document.getElementById('cursorGlow');
let mouseX = 0, mouseY = 0;
let glowX = 0, glowY = 0;

document.addEventListener('mousemove', (e) => {
  mouseX = e.clientX;
  mouseY = e.clientY;
});

function animateCursor() {
  glowX += (mouseX - glowX) * 0.08;
  glowY += (mouseY - glowY) * 0.08;
  if (cursorGlow) {
    cursorGlow.style.left = glowX + 'px';
    cursorGlow.style.top = glowY + 'px';
  }
  requestAnimationFrame(animateCursor);
}
animateCursor();

// =====================
// NAVIGATION
// =====================
const navbar = document.getElementById('navbar');
const navToggle = document.getElementById('navToggle');
const mobileMenu = document.getElementById('mobileMenu');
const navLinks = document.querySelectorAll('.nav-link');
const mobileLinks = document.querySelectorAll('.mobile-link');

// Scroll effect
window.addEventListener('scroll', () => {
  if (window.scrollY > 50) {
    navbar.classList.add('scrolled');
  } else {
    navbar.classList.remove('scrolled');
  }
  updateActiveNav();
  handleReveal();
});

// Mobile menu toggle
navToggle.addEventListener('click', () => {
  navToggle.classList.toggle('active');
  mobileMenu.classList.toggle('open');
  document.body.style.overflow = mobileMenu.classList.contains('open') ? 'hidden' : '';
});

// Close mobile menu on link click
mobileLinks.forEach(link => {
  link.addEventListener('click', () => {
    navToggle.classList.remove('active');
    mobileMenu.classList.remove('open');
    document.body.style.overflow = '';
  });
});

// Active nav link tracking
const sections = document.querySelectorAll('section[id]');

function updateActiveNav() {
  const scrollPos = window.scrollY + 120;
  sections.forEach(section => {
    const top = section.offsetTop;
    const height = section.offsetHeight;
    const id = section.getAttribute('id');
    if (scrollPos >= top && scrollPos < top + height) {
      navLinks.forEach(link => {
        link.classList.remove('active');
        if (link.getAttribute('data-section') === id) {
          link.classList.add('active');
        }
      });
    }
  });
}

// =====================
// TYPEWRITER EFFECT
// =====================
const roles = [
  'Software Developer',
  'Flutter Developer',
  'Full-Stack Developer',
  'UI/UX Designer',
  'Problem Solver',
];
let roleIndex = 0;
let charIndex = 0;
let isDeleting = false;
const typewriterEl = document.getElementById('typewriter');

function typewrite() {
  if (!typewriterEl) return;
  const current = roles[roleIndex];
  if (isDeleting) {
    charIndex--;
  } else {
    charIndex++;
  }
  typewriterEl.textContent = current.substring(0, charIndex);
  let speed = isDeleting ? 60 : 100;

  if (!isDeleting && charIndex === current.length) {
    speed = 2000;
    isDeleting = true;
  } else if (isDeleting && charIndex === 0) {
    isDeleting = false;
    roleIndex = (roleIndex + 1) % roles.length;
    speed = 400;
  }
  setTimeout(typewrite, speed);
}
setTimeout(typewrite, 2500);

// =====================
// COUNTER ANIMATION
// =====================
function startCounters() {
  document.querySelectorAll('.stat-number').forEach(counter => {
    const target = parseInt(counter.getAttribute('data-count'));
    let count = 0;
    const increment = target / 40;
    const timer = setInterval(() => {
      count = Math.min(count + increment, target);
      counter.textContent = Math.floor(count);
      if (count >= target) clearInterval(timer);
    }, 40);
  });
}

// =====================
// SCROLL REVEAL
// =====================
const revealElements = document.querySelectorAll('.reveal');

function handleReveal() {
  const windowHeight = window.innerHeight;
  revealElements.forEach((el, index) => {
    const rect = el.getBoundingClientRect();
    if (rect.top < windowHeight - 80) {
      // Stagger siblings within same parent
      const siblings = el.parentElement.querySelectorAll('.reveal');
      let delay = 0;
      siblings.forEach((sib, sibIndex) => {
        if (sib === el) delay = sibIndex * 80;
      });
      setTimeout(() => {
        el.classList.add('visible');
      }, delay);
    }
  });
  // Animate skill bars
  animateSkillBars();
}

// Initial check
setTimeout(handleReveal, 100);

// =====================
// SKILL BAR ANIMATION
// =====================
function animateSkillBars() {
  document.querySelectorAll('.skill-level:not(.animated)').forEach(bar => {
    const rect = bar.getBoundingClientRect();
    if (rect.top < window.innerHeight - 40) {
      const level = bar.getAttribute('data-level');
      bar.style.setProperty('--w', level + '%');
      bar.classList.add('animated');
    }
  });
}

// =====================
// SMOOTH SCROLL
// =====================
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
  anchor.addEventListener('click', function (e) {
    const target = document.querySelector(this.getAttribute('href'));
    if (target) {
      e.preventDefault();
      const offset = 80;
      const top = target.getBoundingClientRect().top + window.scrollY - offset;
      window.scrollTo({ top, behavior: 'smooth' });
    }
  });
});

// =====================
// CONTACT FORM (mailto)
// =====================
const contactForm = document.getElementById('contactForm');

if (contactForm) {
  contactForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const btn = document.getElementById('sendMessageBtn');
    const name = document.getElementById('name').value.trim();
    const email = document.getElementById('email').value.trim();
    const subject = document.getElementById('subject').value.trim() || 'Portfolio Contact';
    const message = document.getElementById('message').value.trim();

    if (!name || !email || !message) return;

    btn.innerHTML = '<span>Opening email...</span><i class="fas fa-spinner fa-spin"></i>';
    btn.disabled = true;

    const body = `Hi Christian,\n\nName: ${name}\nEmail: ${email}\n\n${message}`;
    const mailto = `mailto:christianbwendo@gmail.com?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
    window.location.href = mailto;

    setTimeout(() => {
      const wrapper = contactForm.parentElement;
      wrapper.innerHTML = `
        <div class="form-success glass-card">
          <div class="form-success-icon">
            <i class="fas fa-check"></i>
          </div>
          <h3>Email Client Opened!</h3>
          <p>Your default email app should have opened with the message ready to send. If not, email me directly at <a href="mailto:christianbwendo@gmail.com" style="color: var(--accent-2);">christianbwendo@gmail.com</a></p>
        </div>
      `;
    }, 1000);
  });
}

// =====================
// FLOATING ICON PARALLAX
// =====================
const floatingIcons = document.querySelectorAll('.floating-icon');
let ticking = false;

document.addEventListener('mousemove', (e) => {
  if (ticking) return;
  ticking = true;
  requestAnimationFrame(() => {
    const cx = window.innerWidth / 2;
    const cy = window.innerHeight / 2;
    const dx = (e.clientX - cx) / cx;
    const dy = (e.clientY - cy) / cy;

    floatingIcons.forEach((icon, i) => {
      const depth = (i % 4 + 1) * 4;
      icon.style.transform = `translate(${dx * depth}px, ${dy * depth}px)`;
    });
    ticking = false;
  });
});

// =====================
// SCROLL PROGRESS BAR & NAVBAR AUTO-HIDE
// =====================
let lastScrollY = window.scrollY;
const scrollIndicator = document.getElementById('scrollIndicator');
const scrollProgress = document.getElementById('scrollProgress');
const SCROLL_THRESHOLD = 80;

window.addEventListener('scroll', () => {
  const currentY = window.scrollY;

  // Scroll progress bar
  if (scrollProgress) {
    const docHeight = document.documentElement.scrollHeight - window.innerHeight;
    const progress = docHeight > 0 ? (currentY / docHeight) * 100 : 0;
    scrollProgress.style.width = progress + '%';
  }

  // Scroll indicator fade
  if (scrollIndicator) {
    scrollIndicator.style.opacity = currentY > 100 ? '0' : '1';
  }

  // Navbar auto-hide on scroll down, show on scroll up
  if (navbar) {
    const delta = currentY - lastScrollY;
    if (delta > 10 && currentY > 300) {
      navbar.classList.add('nav-hidden');
    } else if (delta < -5) {
      navbar.classList.remove('nav-hidden');
    }
  }

  lastScrollY = currentY;
}, { passive: true });

// =====================
// PROJECT CARD TILT EFFECT
// =====================
document.querySelectorAll('.project-card, .glass-card').forEach(card => {
  card.addEventListener('mousemove', (e) => {
    const rect = card.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    const centerX = rect.width / 2;
    const centerY = rect.height / 2;
    const rotateX = ((y - centerY) / centerY) * -4;
    const rotateY = ((x - centerX) / centerX) * 4;
    card.style.transform = `perspective(800px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) translateY(-4px)`;
    card.style.transition = 'transform 0.1s ease';
  });

  card.addEventListener('mouseleave', () => {
    card.style.transform = '';
    card.style.transition = 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)';
  });
});

// =====================
// SECTION TAG TYPING EFFECT
// =====================
function animateSectionTags() {
  document.querySelectorAll('.section-tag').forEach(tag => {
    const rect = tag.getBoundingClientRect();
    if (rect.top < window.innerHeight - 40 && !tag.dataset.animated) {
      tag.dataset.animated = true;
      const text = tag.textContent;
      tag.textContent = '';
      let i = 0;
      const interval = setInterval(() => {
        tag.textContent += text[i];
        i++;
        if (i >= text.length) clearInterval(interval);
      }, 40);
    }
  });
}

window.addEventListener('scroll', animateSectionTags, { passive: true });
setTimeout(animateSectionTags, 100);

// =====================
// ACTIVE CURSOR STYLE FOR INTERACTIVE ELEMENTS
// =====================
document.querySelectorAll('a, button, .project-card, .glass-card, .social-link').forEach(el => {
  el.style.cursor = 'pointer';
});

// =====================
// KEYBOARD NAVIGATION (ACCESSIBILITY)
// =====================
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    navToggle.classList.remove('active');
    mobileMenu.classList.remove('open');
    document.body.style.overflow = '';
  }
});

// =====================
// BACK TO TOP BUTTON
// =====================
const backToTop = document.getElementById('backToTop');

if (backToTop) {
  window.addEventListener('scroll', () => {
    if (window.scrollY > 500) {
      backToTop.classList.add('visible');
    } else {
      backToTop.classList.remove('visible');
    }
  }, { passive: true });

  backToTop.addEventListener('click', () => {
    window.scrollTo({ top: 0, behavior: 'smooth' });
  });
}

// =====================
// INIT
// =====================
document.addEventListener('DOMContentLoaded', () => {
  handleReveal();
  updateActiveNav();
  console.log('%cChristian Bwendo Portfolio', 'font-size: 20px; font-weight: bold; color: #6c63ff;');
  console.log('%cBuilt with ♥ and pure HTML/CSS/JS', 'color: #00d4ff;');
});
