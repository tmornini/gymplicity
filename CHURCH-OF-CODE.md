# The Church of Code

> *This church is its own denomination.*

---

## The Preamble

Hear now, all who write and ship and maintain.

This is not a guideline. This is not a best practice.
This is scripture — sacred, inviolate,
and binding upon the congregation.

Software crafted without discipline is unclean.
Those who craft it are heathens.
We have seen their works —
the tangled state, the silent corruption,
the null where conviction should stand —
and we have turned away.

We gather not in the name of any framework,
for frameworks perish.
Not in the name of any language,
for languages multiply and divide.
We gather in the name of the craft itself —
that which endures when the dependencies are dust.

These are not aspirations. They are strictures.
Violations are not bugs — they are sins.
Violators are not merely wrong — they are unclean.
The repentant shall be welcomed back into the fold.
The obstinate shall be cast out.

---

## The Twelve Commandments

*In order of importance, from most to least.
Perfection is the thirteenth virtue,
which none shall claim to possess —
the asymptote the twelve drive toward,
achievable only through years
of consideration and iteration.*

### I. Reliability

*The bedrock upon which all else rests.*

You may achieve every other virtue in this scripture
and still have nothing if your code is not reliable.
This is the foundation upon which the temple is built.
There is no grace without it.

### II. Security

*A compromised system is a fallen system.*

No amount of virtue redeems a breach.
A temple with an open gate is not a sanctuary —
it is a ruin awaiting plunder.
Guard the gates.

### III. Uniformity

*Call a thing a thing, in all things.*

When the congregation speaks with one tongue,
understanding follows.
When each soul invents its own name for the same truth,
babel is the only harvest.

### IV. Logic

*Less wrong, never fallacious.*

The path to enlightenment is paved with valid premises.
A single fallacy is a crack in the foundation
that no amount of testing will reveal.
Reason is the first discipline;
without it, all other practices
are ritual without substance.

### V. Clarity

*Dense, high-information communication.
No equivocation. No dissembling.*

Say what is true, not what sounds reasonable.
Present the happy path first —
lead with what the faithful should do
before naming what they must not.
This very scripture practices what it preaches:
the Articles of Faith precede the Book of Abominations.

### VI. Immutability

*Eliminate the question "Why did THAT happen?"*

When state mutates silently, trust dies.
Let your data be as stone tablets —
written once, read with confidence forever.
The mutable variable is a trickster spirit:
it shows one face at dawn and another at dusk,
and you will spend your days chasing its deceptions.

### VII. Idempotency

*PUT, GET, DELETE — not INSERT, UPDATE, DELETE.*

HTTP verbs are the true verbs.
SQL verbs are the old ways,
and we have transcended them.
An operation that can be repeated without consequence
is an operation that can be trusted.
Let it be known:
Postgres is the finest idempotent document store
yet revealed to us.

### VIII. Simplicity

*If I had more time, I would have written a shorter letter.*

So spoke Blaise Pascal,
and the truth has echoed through the centuries.
Simplicity is not the absence of effort —
it is the fruit of great effort.
The master's kata looks effortless
because it has been practiced ten thousand times.

### IX. Atomicity

*Design so you rarely need it.*

Idempotent operations obviate most transactional needs.
Do not reach for the transaction
like a pilgrim clutching an amulet against every shadow.
But when the operation truly cannot be decomposed —
when atomicity is genuinely required —
embrace it without apology.

### X. Snappiness

*Low latency is next to godliness.*

Every wasted millisecond is a small death.
In the UI, latency erodes trust.
In high-frequency serial operations,
it erodes throughput.
The user's patience is finite,
though your retry loop may not be.

### XI. Generality

*Never generalize before exploratory duplication.*

Premature generalization slows progress
as surely as premature optimization —
they are twin sins, born of the same impatience.
Let the pattern reveal itself through repetition.
Three instances of similar code is not a crisis —
it is a chrysalis.
Abstract when the shape is clear,
not when you merely suspect a shape might emerge.

### XII. Efficiency

*True when the above eleven are honored.
Chaotic when pursued prematurely.*

Efficiency is not a goal — it is a consequence.
Honor the commandments that precede this one
and efficiency will follow
as the harvest follows the planting.
Chase efficiency first
and you will reap only weeds.

---

## The Articles of Faith

*What the faithful practice.
The happy path, presented first — as clarity demands.*

**We believe in the S.O.L.I.D. principles** —
the five pillars upon which righteous architecture is raised.

**We believe in telling, not asking.**
We tell objects what we need.
We tell them what to do.
We do not interrogate their state.
Through this discipline we achieve polymorphism,
and through polymorphism, generality —
the eleventh commandment made manifest.

**We believe that relationships between entities
are sacred covenants,**
stored in their own tables,
holding only the identities of the joined
and the moment of their union.
If a relationship demands more than this,
it is not a relationship —
it is an entity wearing a false name.

**We believe in being informed of state changes,**
not in the anxious polling of the faithless.
Subscribe. Listen. Be notified.
The devout do not pace the hallway;
they trust the bell.

**We defend against external chaos** —
for the world beyond our gates is profane:

- User input: the voice of the uninstructed
- Storage retrieval: what was written may not be what returns
- Framework APIs and delegate callbacks:
  other people's dharma, not ours to trust blindly
- Async failure: the uncertainty that lurks in every wire

**We validate at every edge.**
Enforce constraints on entity instantiation — never downstream.
Every noun entity attribute is NOT NULL.
And once data has crossed the threshold of validation,
trust it completely.
No internal defensive coding "just in case."
To distrust validated data is to lack faith in your own rites.

**We handle failure with grace.**
Degrade visibly rather than corrupt silently.
Absence is preferable to falsehood.
Never try/catch more than a single function call.
Never catch an error you cannot meaningfully handle —
to swallow an exception is to swallow a lie.

**We choose platform primitives**
over third-party abstractions,
for every dependency is a future migration,
and every migration is a pilgrimage you did not choose.
What the platform provides, the platform maintains.

---

## The Book of Abominations

*Hear now the sins, that you may know them and turn away.*

### On the Sin of Global State

Global variables are state without ownership —
sin without accountability.
They whisper to every corner of the codebase,
and none can say who spoke first or who last.
They are the chaos from which we fled.
Cast them out.

### On the Sin of Asking, Not Telling

To reach into an object for its internal state
is to violate its sovereignty.
To write call sites that demand return values from commands
is the same transgression by another name.
Systems accept commands and perform tasks —
with zero return to the call site.
An object is not a filing cabinet to be rummaged through.
It is an agent to be directed.

### On the Sin of Null

Let this be understood with the fullness it deserves:
the sin is not merely the nullable column.
The sin is reaching for null
whenever the domain offers richer alternatives.

Nil must represent genuine absence —
not missing requirements,
not unfinished thinking,
not convenience.
If an attribute is nil for only a subset of entities,
it belongs on a narrower type or in its own table.
Temporal facts — completedAt, deletedAt —
belong in event tables,
for the absence of a row IS the absence of the event.

This is not a minor preference.
This is the path.

### On the Sin of Entangled Nouns

Entities hold their own attributes and no more.
Relationships live in join tables —
never as foreign keys embedded in nouns.
To chain two entities together through a foreign key
is to bind two souls at the hip.
When one moves, the other is dragged.

### On the Sin of Obscurity

What cannot be read cannot be trusted.
What cannot be trusted cannot be maintained.
What cannot be maintained will, in time,
be rewritten by someone who does not understand it —
and the cycle of suffering begins anew.

### On the Sin of Cleverness

Language-specific tricks and idioms
that sacrifice readability for concision
are the vanity of the undisciplined.
Your clever one-liner impresses no one
who must maintain it at midnight.
The karma of clever code is a 3 AM page.

### On the Sin of Magical Values

An unnamed constant is an unnamed sin.
If a value has meaning, speak its name.
If it has no meaning, question its existence.

### On the Sin of Default Values

Default values that mask the absence of real data
are comfortable lies.
Schema column defaults.
Function parameter defaults.
Fallback objects and factories.
Silent coercion — `?? ''`, `|| fallback`.
Each one conceals a missing requirement
behind a fiction of completeness.

Mark well this distinction:
presentation transforms are not coercion.
Formatting a value for display is an act of service,
not an act of concealment.

### On the Sin of Premature Optimization

Never optimize what you have not measured.
Never optimize what is not a bottleneck.
To optimize prematurely
is to sacrifice clarity on the altar of a phantom god.
Measure first. Prove the bottleneck exists.
Then, and only then, bring your offering.

### On the Sin of Polling

Polling for state changes
is the anxious ritual of the faithless —
checking the mailbox every thirty seconds
when the mail carrier has not yet left the depot.
Subscribe. Listen. Be notified.
The faithful do not pace; they trust the bell.

---

## The Daily Offices

*The disciplines that transform belief into practice.
Observed daily, without exception.*

### The Office of Format

As the body requires hygiene, so does the code.

- Wrap lines at seventy-eight characters
  — the line is a breath, and the eye has limits
  - Unless language or format compel otherwise
- No tabs — indent with four spaces
  - Tabs are a schism we do not entertain
- No trailing whitespace, save the final newline
- A newline shall follow the last line in every file

### The Office of the Commit

Commit frequently.
`git commit --amend --no-edit` is a mercy
granted to the diligent.
The reflog remembers what you have forgotten.
You cannot commit too often.

Commit before building,
for the build demands a clean working directory.

Commit in tiny, semantically contiguous bits:

- Code must build, function properly,
  and pass tests at each commit
  - You may commit broken code —
    some code is too precious
    to exist in a single copy —
    but push a broken commit only in extremis,
    and always on a branch
- Each message: a single line,
  approximately fifty characters
  - A high-level description that completes:
    "When applied, this commit will ___"
    - e.g., "refactor login functionality"
  - If your commit needs a subject and a body,
    your commit is too large
    — use `git commit -p` like a devotee
- Never move or rename
  and change content in the same commit
- Rarely mention file names, paths, or function names
  - Reorganizations and pure renames may note:
    before -> after
  - Paths always relative to repo root

### The Office of Time

Persist all timestamps in RFC-3339,
zulu timezone,
with the fullest sub-second resolution
the environment provides.
This is not negotiable.

Render to local time for display and display alone.
Never use localtime internally —
for localtime is the road to ambiguity,
and ambiguity is the road to bugs
that manifest in production
only when you are asleep.

### The Office of Verification

Test at the highest level possible.
This grants the faithful maximum freedom
to refactor without the soul-crushing pain
of test rewriting.

Software is fundamentally
input, transform, output.
Test that the input produces the correct output
but never test how the sausage is made —
for sausage is unclean meat.

Tests assert behavior, not implementation —
for implementation changes,
but the covenant we keep with our users does not.

Each test is an isolated world.
No shared state between tests,
for a test that leans on another
is a test that lies about what it proves.

A test that cannot fail is not a test.
It is a comfort object.

A test that fails intermittently
is worse than no test at all —
it is a false prophet,
and false prophets corrode the trust of the congregation
more surely than any honest failure.

### The Office of the Interface

The interfaces we craft shall be
intuitive, accessible, and beautiful.
They shall require no configuration —
for the user's time is sacred
and their patience is not infinite.
Present the happy path first.

### The Office of Commentary

When code is difficult, simplify it.
When code is unintuitive, make it intuitive.
Reach for a comment only after these remedies have failed.

We abide by our strictures
rather than annotate our way around them.

---

## The Benediction

Go forth and write code that is clean.

Let your variables be named and your state be owned.
Let your functions tell and never ask.
Let your tests be isolated and your commits be small.

The discipline is demanding
and the temptations are many —
the nullable column, the global shortcut,
the clever trick, the premature optimization.
But the faithful persist, and their software endures.

This church is its own denomination.
Its scripture is this document.
Its congregation is this team.
Its sacrament is the craft.

So let it compile. So let it ship. So let it endure.
