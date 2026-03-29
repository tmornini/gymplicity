# CHURCH-OF-CODE.md Design Spec

## Context

The project's coding standards document (CONDUCT-OF-CODE.md) already
carries proto-religious DNA: "strictures," "inviolate," "heathen,"
"cast out," "godliness." The rename to CHURCH-OF-CODE.md completes
the transformation — rewriting the document as a structured catechism
in the voice of a tent-revival preacher.

**Goal:** Make a coding standards document that people actually want
to read. The humor emerges from dead-serious technical content
delivered with revival-preacher rhetorical flourishes — not from
jokes. A reader should be able to strip the framing and find a
rigorous standards doc underneath.

**Audience:** Small team of developers who share the author's
sensibilities. Humor should land with engineers who get the vibe.

**Heat level:** Tent revival — full Southern-preacher cadence,
dramatic but clearly having fun with itself.

**Scope:** Full rethink — restructure sections, refine tenets,
revisit hierarchy. Not just a prose reskin.

## Structure: Six-Part Catechism

### 1. The Preamble

8-12 lines. A founding declaration / creation myth.

Establishes:
- Software written without discipline is unclean, and those who
  write it are heathens (the sin is in the sinner, not the medium)
- This document is scripture, not guidelines
- Strictures are sacred and inviolate
- Violations are sins, not bugs
- Violators are redeemed or excommunicated
- Perfection is unattainable but pursuit is mandatory

Tone: Opens with conviction, not narrative. More "declaration of
faith" than "once upon a time."

### 2. The Twelve Commandments

The priority-ordered virtues, each as a numbered commandment.

Each commandment follows the pattern:
- **Number and Name** (e.g., "The First Commandment: Reliability")
- **The Decree** — one-line absolute statement
- **The Sermon** — 1-3 lines of elaboration in revival voice

The hierarchy from the current document is preserved:

1. **Reliable** — the bedrock upon which all else rests
2. **Secure** — a compromised system is a fallen system;
   no virtue redeems a breach
3. **Uniform** — call a thing a thing, in all things
4. **Logical** — less wrong, never fallacious
5. **Clear** — dense, high-information communication;
   no equivocation, no dissembling;
   present the happy path first (the document itself
   models this by placing Articles of Faith before
   Abominations)
6. **Immutable** — eliminate "Why did THAT happen?"
7. **Idempotent** — PUT/GET/DELETE, not INSERT/UPDATE/DELETE;
   HTTP verbs over SQL verbs;
   Postgres as idempotent document store
8. **Simple** — Pascal's shorter letter
9. **Atomic** — design to rarely need it;
   idempotency obviates most transactional needs;
   when required, embrace without apology
10. **Snappy** — low latency is next to godliness
11. **General** — never before exploratory duplication;
    premature generalization is premature optimization's
    twin sin
12. **Efficient** — true when the above are honored;
    chaotic when pursued prematurely

Coda: Perfection as "the thirteenth virtue none shall claim
to possess" — the asymptote the twelve drive toward, achievable
only through years of consideration and iteration.

### 3. The Articles of Faith

**Happy path first.** What the faithful practice and believe.

Structured as articles of a creed ("We believe in..."):

- S.O.L.I.D. principles
- Telling, not asking — tell objects what to do;
  exploit polymorphism for generality
- Relationship entities storing only noun IDs and timestamps
  (if it stores more, it is an entity, not a relationship)
- Being informed or notified of state changes (not polling)
- Defending against external chaos:
  user input, storage retrieval, framework APIs, async failure
- Validating at every edge:
  enforce on instantiation, never downstream;
  every noun attribute is NOT NULL;
  trust data after validation — no internal defensive coding
- Handling failure with grace:
  degrade visibly rather than corrupt silently;
  absence over falsehood;
  never try/catch more than a function call;
  never catch what you cannot meaningfully handle
- Platform primitives over third-party abstractions:
  every dependency is a future migration

### 4. The Book of Abominations

**Then the sins.** Each abomination gets:

- **A denunciation header** (e.g., "On the Sin of Global State")
- **The condemnation** — the rule
- **The wages** — why this sin destroys (1-2 lines, preacher
  cadence, tent-revival heat concentrated here)

Abominations (refined from current "We detest"):

- **Global variables** — state without ownership, sin without
  accountability
- **Asking, not telling** — reaching into objects for internal
  state; writing call sites that demand return values from
  commands; systems accept commands and perform tasks with zero
  return to the call site
- **The null of the matter** — the broad sin of reaching for null
  when the domain offers richer alternatives:
  nil must represent genuine absence, not missing requirements;
  if an attribute is nil for a subset of entities, it belongs on
  a narrower type or its own table;
  temporal facts belong in event tables — the absence of a row
  is the absence of the event
- **Foreign keys in nouns** — entities hold their own attributes,
  no more
- **Obscurity** — what cannot be read cannot be trusted
- **Coding cleverness** — language-specific tricks and idioms that
  sacrifice readability for concision
- **Magical values** — unnamed constants are unnamed sins
- **Default values that mask absence** — schema column defaults,
  function parameter defaults, fallback objects, silent coercion;
  presentation transforms are not coercion
- **Premature optimization** — never optimize what you haven't
  measured, never optimize what isn't a bottleneck
- **Polling for state changes** — the faithless checking the
  mailbox every thirty seconds

### 5. The Daily Offices

Practical disciplines, framed as daily devotionals / rites
of observance. Each "office" is a named practice area:

- **The Office of Format**
  - 78 characters maximum line length
    (unless language or format require otherwise)
  - No tabs; indent with 4 spaces
  - No trailing whitespace (other than newline)
  - Newline required after last line in file

- **The Office of the Commit**
  - Commit frequently (amend is a thing; reflog is your friend)
  - Before building (clean working directory required)
  - In tiny, semantically contiguous bits
  - Code must build, function, and pass tests at each commit
    - Broken code may be committed but rarely pushed
      (some code is too valuable for a single copy —
      but it must be on a branch)
  - Single-line messages, ~50 characters
    - Completes: "When applied, this commit will: ___"
    - If you need a subject and body, your commit is too large
    - Use git commit -p like a pro
  - Never move/rename AND change content simultaneously
  - Rarely mention file names or function names
    - Reorganizations and pure renames may
    - Always denoted as: before -> after
    - Paths relative to repo root

- **The Office of Time**
  - Persist all timestamps as RFC-3339, zulu timezone,
    maximum sub-second resolution
  - Render to local time for UI display only
  - Never use localtime internally

- **The Office of Verification**
  - Test at the highest level possible — this grants maximum
    freedom to refactor without the soul-crushing pain of
    test rewriting
  - Software is fundamentally input -> transform -> output;
    test that input produces the correct output but never
    how the sausage (unclean meat) is made
  - Tests assert behavior, not implementation
  - Each test is an isolated world (no shared state)
  - A test that cannot fail is not a test
  - A test that fails intermittently is worse than no test

- **The Office of the Interface**
  - Intuitive, accessible, beautiful
  - Requires no configuration
  - Present the happy path first

- **The Office of Commentary**
  - Simplify rather than comment
  - Make intuitive before commenting
  - Abide by these strictures rather than explain around them

### 6. The Benediction

3-5 lines. Echoes the preamble. A call to go forth and write
clean code. Ends with a communal closing — not "Amen" directly,
but something that rhymes with the revival spirit while staying
in the code domain. Perhaps: "So let it compile. So let it ship."
or similar.

## Tonal Guidelines

- **Contrast is the comedy.** The technical content is dead
  serious. The delivery is revival-preacher. The humor lives
  in the gap between form and content.
- **No winking.** The document never acknowledges it's being
  funny. The preacher is sincere. The congregation knows.
- **Cadence matters.** Use repetition, parallel structure,
  rhetorical questions, and escalation — the tools of both
  great sermons and great technical writing.
- **No specific theology.** No Jesus, no Buddha, no
  Mohammed, no Bible verses, no denominational doctrine.
  Draw vocabulary from the world's traditions — the terms
  that have already crossed into common English and need
  no footnotes. Christianity: sin, redemption, scripture,
  commandment, congregation, sermon, benediction.
  Judaism: covenant, observance, the law. Islam: the
  faithful, the path, submission. Buddhism: enlightenment,
  attachment, suffering. Hinduism: karma, dharma, mantra.
  General: sacred, profane, heresy, orthodox, revelation,
  pilgrimage, devotion. Use them naturally, not as a
  checklist. The reader should chuckle in recognition
  when a term from their own tradition appears. The church
  is its own denomination — ecumenical by instinct.
- **Ecclesiastical doom, not tech punchlines.** The threats
  stay in the revival register — vague, ominous, theatrical.
  "Low latency is next to godliness" lands. "Suffer the
  lowly fate of the unwashed" lands. "BURN IN PROD" does
  not — it's a tech joke in a religious costume. Keep the
  doom ecclesiastical, not operational.
- **The document practices what it preaches.** Happy path
  first (Articles of Faith before Abominations). Clear.
  Dense. No equivocation.

## Key Content Changes from Current Document

1. **Structural overhaul** — from flat bulleted lists to
   six-part catechism with named sections
2. **Happy path first** — Articles of Faith before
   Abominations (current doc leads with "We detest")
3. **Null treatment broadened** — not just nullable columns,
   but the general sin of choosing null when richer
   alternatives exist
4. **"Present the happy path first" added as a tenet** —
   under Clarity, and modeled by the document structure
5. **Perfection reframed** — from a list item to "the
   thirteenth virtue none shall claim to possess"
6. **Each section has a distinct rhetorical register** —
   Preamble (declarative), Commandments (decretal),
   Articles (credal), Abominations (denunciatory),
   Offices (instructional), Benediction (invocational)

## File Changes

- **Delete:** `CONDUCT-OF-CODE.md`
- **Create:** `CHURCH-OF-CODE.md`
- **Update:** `CLAUDE.md` — reference new filename
- **Update:** Any other files referencing the old name

## Verification

- Read the final document end-to-end for tonal consistency
- Confirm every technical rule from the original document
  is present (nothing lost in the rewrite)
- Verify the document renders cleanly in GitHub markdown
- Grep the repo for any remaining references to
  CONDUCT-OF-CODE.md
