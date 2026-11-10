# Red flags

Probes from Ousterhout's *A Philosophy of Software Design*, scoped to interfaces and flows. Check each proposed module, interface and flow against every probe. When one trips, turn it into a question: cite the evidence (a signature, a call site, a prototype diff line) and recommend a fix.

## Modules

- **Shallow module**: the interface is nearly as complex as what it hides. Apply the deletion test. Ask whether to merge it into a caller or a neighbour, or to hide more behind it.
- **Information leakage**: one design decision (a format, a protocol, an ordering) shows up in two or more modules. Ask which single module should own it.
- **Temporal decomposition**: modules split along the order things happen in (read, then parse, then save) rather than by the knowledge each hides. Ask whether the steps share knowledge that belongs in one module.
- **Special-general mixture**: a general-purpose module carries code or parameters for one specific caller. Ask whether the special case belongs in the caller.
- **Repetition**: the same pattern appears across several modules or call sites. Ask whether one module should absorb it.
- **Different layer, same abstraction**: adjacent layers expose nearly identical interfaces. Ask what each layer adds.

## Interfaces

- **Overexposure**: the common case forces callers to learn rarely used options. Ask for a default that makes the common call trivial.
- **Pass-through method**: a method forwards to another with the same signature. Ask whether the layer earns its keep.
- **Pass-through variable**: a value threads through intermediate signatures that only hand it on. Ask for a context object or a different owner.
- **Conjoined methods**: one method is meaningless without reading another (call `init` before `run`, use `open` only with `close`). Ask whether one call can cover both, or the interface can enforce the order.
- **Complexity pushed up**: the interface asks callers for configuration or decisions the module could make itself. Pull complexity downward: ask what sensible behaviour the module could own.
- **Errors passed up by default**: an error mode exists only because the interface allows a state it could rule out. Ask whether to define it out of existence, mask it, or aggregate it.

## Names and comments

- **Hard to name**: no precise name fits, or the best candidate is generic (`Manager`, `Helper`, `Data`, `process`). Ask what the module actually hides; the answer usually holds the name.
- **Hard to describe**: the purpose sentence needs "and", or a paragraph. Ask whether this is two modules.
- **Comment repeats the signature**: the interface comment restates the types. Ask what a caller needs beyond them: invariants, units, ordering, error meaning.
- **Implementation in the interface comment**: the comment explains how the module works inside. Ask what callers need, and move the rest into the implementation.
