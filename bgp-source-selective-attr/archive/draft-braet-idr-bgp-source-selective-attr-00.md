---
title: BGP Source-Selective Attribute
abbrev: BGP-SSA
docname: draft-braet-idr-bgp-source-selective-attr-00
date: 2026-06-16
category: std

ipr: trust200902
area: Routing
keyword: Internet-Draft

stand_alone: true
pi: [toc, sortrefs, symrefs]
submissiontype: IETF
workgroup: idr

author:
  ins: K. Braet
  name: Kamiel Braet
  organization: Liberty Global Ltd.
  email: kabraet@libertyglobal.com
  country: Netherlands

normative:
  RFC2119:
  RFC4271:
  RFC2827:
  RFC3704:
  RFC7606:
  RFC8704:
informative:
  I-D.braet-idr-source-selective-bgp-framework:
    title: "Source-Selective BGP Framework"
    author:
      ins: K. Braet
      name: Kamiel Braet
      org: Liberty Global Ltd.
    seriesinfo:
      Internet-Draft: draft-braet-idr-source-selective-bgp-framework
    date: 2026
  I-D.braet-sidrops-spa-profile:
    title: "A Profile for Source Prefix Authorizations (SPAs)"
    author:
      ins: K. Braet
      name: Kamiel Braet
      org: Liberty Global Ltd.
    seriesinfo:
      IETF: draft-braet-sidrops-spa-profile
    date: 2026
  RFC8210:
  RFC9234:

--- abstract

This document specifies a new Border Gateway Protocol (BGP) Path Attribute, the BGP SOURCE_SELECTIVE Attribute. This attribute allows BGP speakers to reference Resource Public Key Infrastructure (RPKI) Source Authorization (SA) objects, including Source Prefix Authorization (SPA), within BGP UPDATE messages. These objects are created by prefix holders to define sources authorized to originate traffic toward their prefixes or subprefixes. Receiving BGP speakers can use this information to enforce security policies.

The SOURCE_SELECTIVE Path Attribute supports multiple Source Authorization Identifier (SA-ID) fields to preserve authorization semantics during BGP route aggregation and summarization.

This mechanism applies to BGP AFI 1 / SAFI 1 (IPv4 Unicast) and AFI 2 / SAFI 1 (IPv6 Unicast).

--- middle

# Introduction

BGP provides reachability information for IP prefixes, but does not express which sources are authorized to send traffic to those prefixes. Destination networks must rely on out-of-band mechanisms to express source-based intent, particularly for denial-of-service mitigation, infrastructure protection, and restricted-access services.

This document defines new optional transitive BGP Path Attribute called SOURCE_SELECTIVE, which enables a prefix holder to:

* Bind BGP advertisements using SOURCE_SELECTIVE Path Attribute to one or more RPKI Source Authorization (SA) objects.
* Preserve authorization information during BGP route aggregation.

Each BGP speaker supporting SOURCE_SELECTIVE as described in this document is expected to communicate with one or more RPKI caches, each of which stores a local copy of the global RPKI database. The protocol mechanisms used to gather and validate these data and present them to BGP speakers are described in [RFC8210]. An informative blueprint mapping these data payloads to expected RPKI-to-Router protocol extensions is detailed in Appendix A.

SOURCE_SELECTIVE complements, but does not replace, existing BGP Community mechanisms.

This mechanism does not modify BGP NLRI semantics and does not mandate enforcement behavior.

This document is part of the Source-Selective BGP framework [I-D.braet-idr-source-selective-bgp-framework], which defines an architecture consisting of RPKI Source Authorization objects and a BGP Path Attribute used to reference them. The SOURCE_SELECTIVE Path Attribute provides a mechanism to bind BGP reachability information to holder-signed source authorization data, without altering BGP route selection or mandating enforcement behavior.

# Terminology

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in [RFC2119].

* Source Authorization (SA): An RPKI Object created by prefix holders to define sources authorized to originate traffic toward their prefixes or subprefixes. Examples include SPA and SGA RPKI Object types.
* Source Prefix Authorization (SPA): A set of Source IP address prefixes authorized to send packets to a destination prefix published in RPKI as specified in [I-D.braet-sidrops-spa-profile]
* SOURCE_SELECTIVE: The BGP Path Attribute that references one or more RPKI Source Authorization (SA) objects as specified in this document.
* Source Authorization Identifier (SA-ID): A SOURCE_SELECTIVE sub-TLV field that encapsulates a network prefix structure, serving as a data-plane lookup key to reference a specific validated RPKI SA object within a router's local cache..
* Source Address Validation (SAV): Techniques that prevent packets with spoofed source addresses from entering or traversing a network.
* SPA-v4 and SPA-v6: In this document, the terms SPA-v4 and SPA-v6 are used informatively to refer to IPv4 and IPv6 instantiations of the Source Prefix Authorization (SPA) object, respectively.

# Architecture Overview

BGP SOURCE_SELECTIVE Attribute operates as follows:

1. A prefix holder creates a list of Sources authorized to send packets to the holder's destination prefix or a designated subprefix of that prefix.
2. The list is published as one or more Source Authorization (SA) Objects. For example Source Prefix Authorization (SPA) Objects.
3. The destination prefix is advertised via BGP.
4. The BGP UPDATE includes the SOURCE_SELECTIVE Path Attribute referencing SA object(s) using one or more Source Authorization Identifier (SA-ID) fields.
5. Receiving networks MAY use the SA objects to apply source-based policy.

RPKI Source Authorization objects are intended to inform local policy decisions rather than to directly affect BGP route selection.

The SOURCE_SELECTIVE Path Attribute is optional, transitive, and summarization-safe.

## Design Rationale

This subsection is non-normative.

The SOURCE_SELECTIVE Path Attribute associates RPKI objects (e.g. SPA) with specific BGP route advertisements while preserving BGP semantics. RPKI provides verifiable assertions about which sources are authorized to originate traffic for a given prefix, but it does not define how such assertions are associated with BGP routes. SOURCE_SELECTIVE allows a BGP speaker to reference these holder-signed objects without embedding authorization data directly in BGP.

Route aggregation can obscure authorization semantics tied to more specific prefixes. By allowing multiple RPKI references to be attached to an aggregated route, the attribute preserves this context that would otherwise be lost.

The attribute is optional, does not affect BGP route selection, and does not mandate enforcement. Networks that do not recognize it propagate it unchanged; networks that do may use the references as input to local policy decisions.

Unlike BGP Communities, which are applied per AS and reflect operational policy, the SOURCE_SELECTIVE Path Attribute carries references to RPKI objects created and signed by the IP prefix holder. This ensures that the attribute conveys holder-authorized source information, rather than unverified operational intent from intermediate ASes.

# SOURCE_SELECTIVE Path Attribute

## Overview

The SOURCE_SELECTIVE Path Attribute provides a reference to one or more Source Authorization (SA) objects associated with the advertised NLRI.

## Attribute Properties

* Attribute Type Code: TBD (IANA-assigned)
* Attribute Flags:
  * Optional
  * Transitive
  * Partial: per [RFC4271]
  * Extended Length: as required
* Applicable AFI/SAFI:
  * AFI 1 / SAFI 1
  * AFI 2 / SAFI 1

## Attribute Encoding

The SOURCE_SELECTIVE Path Attribute is encoded using the standard BGP Path Attribute format defined in [RFC4271].

The complete encoding is as follows:

~~~~~~~~~~
+------------------------------+
| Attribute Flags              | 1 octet
+------------------------------+
| Attribute Type Code          | 1 octet (TBD, IANA-assigned)
+------------------------------+
| Attribute Length             | 1 or 2 octets
+------------------------------+
| Number of SA-ID TLVs         | 2 octets
+------------------------------+
| SA-ID TLVs                   | variable length
+------------------------------+
~~~~~~~~~~

* The Attribute Flags field is set as specified in Section 4.2.
* The Attribute Type Code identifies the SOURCE_SELECTIVE Path Attribute and is assigned by IANA.
* The Attribute Length field encodes the length, in octets, of the Attribute Value field. A one-octet or two-octet length field is used depending on whether the Extended Length flag is set, as specified in [RFC4271].
* The Number of SA-ID (Source Authorization Identifier) TLVs indicates the total number of SA-ID TLVs that follow.
* SA-ID TLVs are encoded sequentially, with no padding between fields.

If the total Attribute Length exceeds 255 octets, the Extended Length flag MUST be set and a two-octet Attribute Length field used, as specified in [RFC4271].

## SA-ID TLV Format 

Each SA-ID Field is encoded as a TLV (Type-Length-Value) structure, allowing multiple policy types to coexist and enabling future extensibility. 

The SA-ID TLV defines a common identification framework for Source Authorization objects that are anchored to an IP address prefix. The prefix encoding maps directly to the target network prefix space, enabling routers to index and query their local RPKI cache tables.

### Encoding
~~~~~~~~~~
+------------------------+
| SA Type (TLV Type)     | 1 octet (IANA-assigned)
+------------------------+
| TLV Length             | 2 octets
+------------------------+
| Prefix Length          | 1 octet
+------------------------+
| Protected Prefix       | 4 octets (IPv4) or 8 octets (IPv6)
+------------------------+
~~~~~~~~~~

* SA Type (TLV Type): Indicates the type of referenced RPKI Source Authorization (SA) object and IP address family. Example assignments (by IANA):  
  * 0x01 = IPv4 Source Prefix Authorization (SPA-v4)
  * 0x02 = IPv6 Source Prefix Authorization (SPA-v6)
  * 0x03-0xFF = reserved for future types  
* TLV Length: Length, in octets, of the Prefix Length and Protected Prefix fields combined.
* Prefix Length: Length, in bits, of the Address Prefix.
* Protected Prefix: Address prefix followed by enough trailing bits to make the field 4 octets (IPv4) or 8 octets (IPv6) long.

### Semantics

The SA-ID TLV Value MUST encode the prefix length and the protected prefix associated with the referenced Source Authorization (SA) object. The IP version of the protected prefix is implicitly determined by the SA Type.

For IPv4 SA Types, the Protected Prefix field MUST be encoded as 4 octets. For IPv6 SA Types, the Protected Prefix field MUST be encoded as 8 octets, representing the 64 most significant bits of the IPv6 address. Bits beyond the first 64 are not represented and are implicitly set to zero.

The SA-ID TLV Value does not encode repository locations, filenames, or Uniform Resource Identifiers (URIs). Resolution of SA-IDs MUST be performed exclusively by exact matching against locally cached Source Authorization PDUs received via the RPKI to Router (RTR) protocol (see Appendix A for an abstract overview of this cache synchronization model).

## Semantics of Multiple SA-ID Value Fields

Each SA-ID field in the SOURCE_SELECTIVE Path Attribute MUST encode a protected IP address prefix. When multiple SA-ID fields are present within a single attribute, they MUST be evaluated as an open set of independent lookup keys.

Duplicate combinations of SA Type, Prefix Length, and Protected Prefix within the same attribute carry no additional meaning and MUST be ignored by the receiving BGP speaker.

BGP speakers MAY include multiple SA-ID fields for a given NLRI when advertising aggregated or summarized routes. Each individual field preserves the cryptographic lookup mapping for a specific contributing subprefix, ensuring that downstream routers can validate the distinct source constraints applied to different components of the aggregated block.

## Support for Route Summarization

When performing route aggregation or summarization, a BGP speaker SHOULD copy the SA-ID fields from all contributing routes into the SOURCE_SELECTIVE attribute of the new aggregated route. This ensures that source constraints tied to more specific prefixes are not silently discarded during control plane propagation.

If the total length of the combined SA-ID fields exceeds local implementation or hardware constraints, or if the applicability of a specific protected prefix to the broader aggregated block cannot be verified, the aggregating router MAY selectively omit fields.

Implementations SHOULD impose configurable maximum limits on the number of SA-ID fields allowed in a single BGP UPDATE to mitigate resource exhaustion or excessive message sizing.

## Processing Rules

BGP speakers receiving the SOURCE_SELECTIVE attribute MUST process it as an optional transitive attribute in accordance with the error-handling procedures in [RFC7606].

* Validation failure of referenced RPKI SA Objects MUST NOT invalidate the route.
* Unsupported BGP speakers MUST propagate the attribute unchanged.
* SA-ID fields in the attribute are logical references and MUST NOT be interpreted as instructions to retrieve objects.
* Retrieval and validation of RPKI data are performed via local caches using existing mechanisms (see Appendix A).
* Validated SA Object data MAY be used to enforce policies restricting IP packet forwarding based on source authorization.
* Resolution of SA-IDs TLV MUST be performed by exact data-field matching of the Protected Prefixes against the local cache.
* SA-ID processing SHOULD be consistent across enforcement points to prevent unintended traffic drops or acceptance of unauthorized traffic.
* TLVs of unknown SA Type MUST be propagated unchanged.

# Operational Considerations

BGP SOURCE_SELECTIVE Attribute is intended to be incrementally deployable and does not require universal support to be useful.

## Operational Guidance

### Route Processing and Resource Optimization

Hardware Optimization: An implementation MAY constrain policy enforcement to local AS prefixes and the prefixes of directly connected AS networks acting in a customer role, as identified via ASPA, via eBGP Role Detection [RFC9234], or via other administrative or out-of-band means. This excludes the broader customer cone to optimize hardware lookup tables.

Table Resource Reduction: When implementing Source Prefix Policies, operators MAY use RPKI ROA and ASPA information to eliminate irrelevant Source Prefix Policy entries from allowlists. This reduces table resource consumption by removing unnecessary allowlist entries and strengthens Source Address Validation (SAV), as some packets with spoofed source IP addresses that would otherwise match allowlist entries will be filtered.

Route Aggregation Policies: Aggregation policies MAY include Source Authorization (SA) Identifier Value fields of contributing routes in SOURCE_SELECTIVE Path Attributes whenever feasible.

Aggregation Risks: Operators SHOULD take into account that SOURCE_SELECTIVE Attributes may be omitted by upstream networks when networks not supporting the SOURCE_SELECTIVE Path Attribute perform aggregation.


### Policy Enforcement and Monitoring

SAV Integration: Enforcement of SOURCE_SELECTIVE Attribute Source Authorization is most effective when combined with Source Address Validation (SAV).

Policy Consistency: Operators SHOULD ensure consistent validation and policy application across enforcement points.

Traffic Protection: Source Authorization policies MAY include mechanisms to protect traffic from congestion or overload caused by other traffic sharing the same network resources, particularly in scenarios where other traffic classes have increased exposure to overload or denial-of-service attacks.

Telemetry and Diagnostics: Monitoring and telemetry systems SHOULD distinguish between routing reachability and source authorization failures.

Source Selective signaling SHOULD be treated as an input to local policy, not as an unconditional authorization decision.

## Scaling Considerations

SOURCE_SELECTIVE Attribute is designed to scale in large BGP deployments by offloading most policy data to RPKI objects, carrying only compact references in BGP UPDATE messages.

* Limits per UPDATE: Implementations SHOULD impose configurable limits on the number of SA-ID TLVs per NLRI to prevent excessive BGP UPDATE message sizes and reduce CPU and memory load.
* Aggregation behavior: When aggregating multiple prefixes, SA-ID TLVs MAY be selectively included to maintain authorization semantics while avoiding unnecessary growth of attribute size.
* Propagation control: As a transitive attribute, SOURCE_SELECTIVE will be propagated by default. Operators MAY filter or limit TLVs on peering sessions to reduce unnecessary propagation, similar to practices used for BGP Communities.
* Caching and pre-validation: RPKI caches can be used to pre-validate referenced SA objects, minimizing per-update processing overhead on routers.

By keeping only source IP address prefix references in the BGP attribute, the SOURCE_SELECTIVE design balances security expressiveness with operational scalability, and avoids the scaling challenges historically associated with large per-prefix metadata, such as extensive Communities or Extended Communities usage.

# Security Considerations

The Source Prefix Policies do not prevent source address spoofing on networks that do not implement Source Address Validation (SAV), as described in [RFC2827], [RFC8704], and [RFC3704]. Enforcement of Source Prefix Policies may be ineffective or incomplete in the presence of spoofed source addresses.

Source Prefixes are published in publicly accessible RPKI repositories and may reveal information about communication relationships or traffic patterns. To mitigate these risks, an AS network MAY choose to limit the advertisement or use of Source Prefix Policy-enabled routes to networks that:

* Explicitly support the SOURCE_SELECTIVE Path Attribute and the RPKI SPA Policies,
* Limit Source Prefix Policies Allowlist entries based RPKI ROA and ASPA information, and
* Apply SAV on customer and interconnection interfaces.

Such limitations are optional but improve source-based authorization effectiveness and reduce abuse risk.

Failure to validate Source Prefix Authorization (SPA) objects correctly, or to apply consistent policy across enforcement points, may result in unintended traffic drops or acceptance of unauthorized traffic.

Implementations should validate TLV sizes carried in the SOURCE_SELECTIVE attribute and reject extreme updates.

SOURCE_SELECTIVE attribute relies on RPKI to ensure that only legitimate holders of IP address prefixes can publish Source Authorization (SA) objects. Integrity and authenticity of SA objects depend on correct RPKI certificate issuance, publication, and validation.

# IANA Considerations

IANA is requested to assign a value to the Source Selective (SOURCE_SELECTIVE) Path Attribute in the "BGP Path Attributes" subregistry under the "Border Gateway Protocol (BGP) Parameters" registry.

IANA is requested to establish a SOURCE_SELECTIVE TLV Source Authorization (SA) Type with the following entries:

* 0x01 = IPv4 Source Prefix Authorization (SPA-v4)
* 0x02 = IPv6 Source Prefix Authorization (SPA-v6)
* 0x03-0xFF = reserved

--- back

# Informative Blueprint for RPKI-RTR Protocol Extensions

## Cache Synchronization Abstract

To support the Source-Selective BGP framework, the RPKI-to-Router (RTR) protocol [RFC8210] is extended to transport Validated SPA Payloads (VSPs) from relying party caches to local routers. 

These extensions introduce two new functional PDU types:

1. SPA Announcement PDU: Advertises a valid destination prefix alongside its permitted source prefix boundaries.
2. SPA Withdrawal PDU: Removes a previously signaled SPA profile from the router's local cache.

The exact bit-level wire formats, error codes, and Protocol Data Unit (PDU) structures for these messages are outside the scope of the IDR working group and will be formally specified in a future Standards Track document targeting the SIDROPS working group.

# Acknowledgments
{:unnumbered}

The author would like to thank the individual reviewers from the IETF community for their valuable feedback and contributions during the development of this document.

The design of Source-Selective BGP (SSB) and the specified BGP SOURCE_SELECTIVE Attribute build on decades of work in BGP, RPKI, and secure routing. The author gratefully acknowledges the contributions of the IETF IDR, SIDROPS, and GROW working groups.
