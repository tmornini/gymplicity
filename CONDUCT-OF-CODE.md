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
  - security breaches are to be avoided
- uniform
  - call a thing a thing in all aspects of what we do
- logical
  - we strive to be less wrong and never fallacious
- clear
  - we emphasize dense, high information communication
  - no equivocation
    - say what is true, not what sounds reasonable
  - we never dissemble
- immutable
  - limit the need to ask "Why did THAT happen?"
- idempotent
  - HTTP verbs > SQL verbs
    - PUT/DELETE/POST > CRUD
  - Postgres is the best idempotent document store
- simple
  - if I had more time I'd have written a shorter letter -- Blaise Pascal
- atomic
  - avoid at all costs, thank your God for giving it to you when you can't
- snappy
  - low latency is godliness, essential for UI and high frequency serial ops
- general
  - never before exploratory duplication
  - snappiness development progress rules
- efficient
  - true if above are adhered to
  - chaotic when focused on prematurely
- perfect
  - only asymptotically achievable
  - generally many years of consideration and iteration

We detest:

- global variables
- ask, don't tell
  - we never ask objects for internal attribute values
- nullable attributes
- foreign keys in nouns
- obscurity
- coding cleverness
  - particularly involving language specific
- magical values
- default values — in all forms
  - schema column defaults
  - function parameter defaults
  - fallback objects and factories
  - silent coercion (`?? ''`, `|| fallback`)
  - default values mask absence of real data
  - this does not apply to display formatting
    — presentation transforms are not coercion
- premature optimization
  - never optimize anything
    - that you haven't measured
    - that isn't a bottleneck
- polling for state changes

We adore:

- S.O.L.I.D. techniques (<https://en.wikipedia.org/wiki/SOLID>)
- tell, don't ask
  - we tell objects what we need or what to do
  - this allows us to exploit polymorphism, which allows generality
- relationship entities storing relationships between nouns
  - should only store noun IDs and when the relationship was formed
  - if it needs to store more
    - it's an entity not a relationship
- being informed or notified of state changes
- defending against external chaos
  - user input
  - storage retrieval
  - DOM API
  - async failure
- validate input at every edge
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
- in tiny, semantically continguous bits
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
      - use git commit -p like pro
  - that never moves or renames and change content simultaneously
- rarely mentions file names, paths, pathnames or function names
  - codebase reorganizations moves and renames may
  - pure function and/or file renaming may
  - moves and renames always denoted as
    - before -> after
  - paths and pathnames always relative to repo root
