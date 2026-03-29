# Conduct of Code

All code in this project, and the process of creating it, must adhere to these strictures.

These rules are inviolate, not aspirational.

All violations are defective.

All violators are heathen.

Repeat offenders shall be cast out.

In order of importance, from most to least, our code must be:

- reliable
  - the bedrock upon which everything we do rests
- secure
  - a compromised system is a failed system
  - no amount of other virtue redeems a breach
- uniform
  - call a thing a thing in all aspects of what we do
- logical
  - less wrong, never fallacious
- clear
  - we emphasize dense, high information communication
  - no equivocation
    - say what is true, not what sounds reasonable
  - we never dissemble
- immutable
  - eliminate the question "Why did THAT happen?"
- idempotent
  - HTTP verbs > SQL verbs
    - PUT/GET/DELETE — not INSERT/UPDATE/DELETE
  - Postgres is the best idempotent document store
- simple
  - if I had more time I'd have written a shorter letter -- Blaise Pascal
- atomic
  - design so you rarely need it
  - idempotent operations obviate most transactional needs
  - when genuinely required, embrace it without apology
- snappy
  - low latency is godliness, essential for UI and high frequency serial ops
- general
  - never before exploratory duplication
  - premature generalization slows progress
    as much as premature optimization
- efficient
  - true if above are adhered to
  - chaotic when focused on prematurely

Perfection is the asymptote the above twelve drive toward.
Only achievable through years of consideration and iteration.

We detest:

- global variables
- asking, not telling
  - we never reach into objects for internal state
  - we never write call sites that demand return values from commands
  - systems accept commands and perform tasks
    with zero return to the call site
- nullable attributes
  - nil must represent genuine absence, not missing requirements
  - if an attribute is nil for a subset of entities
    it belongs on a narrower type or in its own table
  - temporal facts (completedAt, deletedAt) belong in
    event tables, not as nullable columns on entities
    — the absence of a row is the absence of the event
- foreign keys in nouns
- obscurity
- coding cleverness
  - particularly language-specific tricks and idioms
    that sacrifice readability for concision
- magical values
- default values that mask absence of real data
  - schema column defaults
  - function parameter defaults
  - fallback objects and factories
  - silent coercion (`?? ''`, `|| fallback`)
  - presentation transforms are not coercion
- premature optimization
  - never optimize anything
    - that you haven't measured
    - that isn't a bottleneck
- polling for state changes

We adore:

- S.O.L.I.D. techniques (<https://en.wikipedia.org/wiki/SOLID>)
- telling, not asking
  - we tell objects what we need or what to do
  - this allows us to exploit polymorphism, which allows generality
- relationship entities storing relationships between nouns
  - should only store noun IDs and when the relationship was formed
  - if it needs to store more
    - it's an entity not a relationship
- being informed or notified of state changes

We defend against external chaos:

- user input
- storage retrieval
- framework APIs and delegate callbacks
- async failure

We validate at every edge:

- enforce on entity instantiation
  - never downstream
- every noun entity attribute is NOT NULL
- trust data after validation
  - no internal defensive coding "just in case"

We handle and persist timestamps uniformly:

- persist all timestamps as RFC-3339
  - zulu timezone
  - with as much sub second resolution as the environment provides
- render to local time for UI display only
  - never use localtime internally

We verify code:

- tests assert behavior, not implementation
- each test is an isolated world
  - no shared state between tests
- a test that can't fail is not a test
- a test that fails intermittently is worse than no test

We handle failure:

- degrade visibly rather than corrupt silently
- absence is preferable to falsehood
- never try/catch more than a function call
- never catch an error you can't meaningfully handle

We prefer platform primitives:

- every dependency is a future migration
- prefer platform primitives over third-party abstractions

We create UIs that are:

- intuitive
- accessible
- beautiful
- don't require configuration

We write and maintain comments when code is:

- difficult
  - simplify rather than comment
- unintuitive
  - make intuitive before comment
- we abide by our strictures rather than write comments

We format code:

- wrapped at 78 characters maximum length
- unless language or format require otherwise
- no tabs
- indent with 4 spaces
- no trailing whitespace, other than newline
- newline required after last line in file

We commit code:

- frequently
  - git commit --amend --no-edit is a thing
  - you can't commit too frequently, reflog is your friend
- before building, which requires a clean working directory
- in tiny, semantically contiguous bits
  - code must build, function properly and pass tests at each commit
    - you can commit broken code, but you should rarely push a broken commit
      - some code is too valuable to have a single copy of
        - but it must be on a branch
  - with a single line message about 50 characters in length
    - is a high level description
    - completes the sentence that begins "When applied, this commit will: "
      - e.g. "refactor login functionality"
    - if you think your commit demands a message with a subject line and body
      - your commit is too large
      - use git commit -p like a pro
  - that never moves or renames and change content simultaneously
- rarely mentions file names, paths, pathnames or function names
  - codebase reorganizations moves and renames may
  - pure function and/or file renaming may
  - moves and renames always denoted as
    - before -> after
  - paths and pathnames always relative to repo root
