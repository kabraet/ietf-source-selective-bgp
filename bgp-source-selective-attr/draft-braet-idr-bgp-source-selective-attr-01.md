---
title: BGP Source-Selective Attribute
abbrev: BGP-SSA
docname: draft-braet-idr-bgp-source-selective-attr-01
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
  organization: Liberty Global
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
  RFC4360:
  RFC8092:
  RFC8126:
  RFC8201:
  RFC8210:
  RFC8899:
  RFC8955:
  RFC9234:

--- abstract

This document specifies a new Border Gateway Protocol (BGP) Path Attribute, the BGP SOURCE_SELECTIVE Attribute. This attribute allows BGP speakers to reference Resource Public Key Infrastructure (RPKI) Source Authorization (SA) objects, including Source Prefix Authorization (SPA), within BGP UPDATE messages. These objects are created by prefix holders to define sources authorized to originate traffic toward their prefixes or subprefixes. Receiving BGP speakers can use this information to enforce security policies.

The SOURCE_SELECTIVE Path Attribute supports multiple Source Authorization Identifier (SA-ID) fields to preserve authorization semantics during BGP route aggregation and summarization.

This mechanism applies to BGP AFI 1 / SAFI 1 (IPv4 Unicast) and AFI 2 / SAFI 1 (IPv6 Unicast).

--- middle

# Introduction {#introduction}

BGP provides reachability information for IP prefixes but does not express which source prefixes are authorized to send traffic to those destinations. As a result, destination networks lack a standardized in-band mechanism to constrain inter-domain IP reachability based on source addresses, requiring out-of-band coordination for network-layer ingress filtering, denial-of-service mitigation, and infrastructure protection.

This document defines new optional transitive BGP Path Attribute called SOURCE_SELECTIVE, which enables a prefix holder to:

* Bind BGP advertisements using SOURCE_SELECTIVE Path Attribute to one or more RPKI Source Authorization (SA) objects.
* Preserve authorization information during BGP route aggregation.

Each BGP speaker supporting SOURCE_SELECTIVE as described in this document is expected to communicate with one or more RPKI caches, each of which stores a local copy of the global RPKI database. The protocol mechanisms used to gather and validate these data and present them to BGP speakers are described in [RFC8210]. An informative blueprint mapping these data payloads to expected RPKI-to-Router protocol extensions is detailed in Appendix A.

SOURCE_SELECTIVE complements, but does not replace, existing BGP Community mechanisms.

This document is part of the Source-Selective BGP framework [I-D.braet-idr-source-selective-bgp-framework], which defines an architecture consisting of RPKI Source Authorization objects and a BGP Path Attribute used to reference them. The SOURCE_SELECTIVE Path Attribute provides a mechanism to bind BGP reachability information to holder-signed source authorization data.

This document specifies the syntax and protocol procedures for the SOURCE_SELECTIVE path attribute. As specified in Section {{impact-on-route-selection}}, this attribute does not alter standard BGP route selection.

For a detailed analysis of why existing community mechanisms (e.g., [RFC4360], [RFC8092]) cannot be used for this signaling, see Section 9.1.5 of [I-D.braet-idr-source-selective-bgp-framework].

# Terminology {#terminology}

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in [RFC2119].

* Source Authorization (SA): An RPKI Object created by prefix holders to define sources authorized to originate traffic toward their prefixes or subprefixes. Examples include SPA and SGA RPKI Object types.
* Source Prefix Authorization (SPA): A set of Source IP address prefixes authorized to send packets to a destination prefix published in RPKI as specified in [I-D.braet-sidrops-spa-profile]
* SOURCE_SELECTIVE: The BGP Path Attribute that references one or more RPKI Source Authorization (SA) objects as specified in this document.
* Source Authorization Identifier (SA-ID): A SOURCE_SELECTIVE sub-TLV field that encapsulates a network prefix structure, serving as a data-plane lookup key to reference a specific validated RPKI SA object within a router's local cache..
* Source Address Validation (SAV): Techniques that prevent packets with spoofed source addresses from entering or traversing a network.
* SPA-v4 and SPA-v6: In this document, the terms SPA-v4 and SPA-v6 are used informatively to refer to IPv4 and IPv6 instantiations of the Source Prefix Authorization (SPA) object, respectively.

# Architecture Overview {#architecture-overview}

BGP SOURCE_SELECTIVE Attribute operates as follows:

1. A prefix holder creates a list of Sources authorized to send packets to the holder's destination prefix or a designated subprefix of that prefix.
2. The list is published as one or more Source Authorization (SA) Objects. For example Source Prefix Authorization (SPA) Objects.
3. The destination prefix is advertised via BGP.
4. The BGP UPDATE includes the SOURCE_SELECTIVE Path Attribute referencing SA object(s) using one or more Source Authorization Identifier (SA-ID) fields.
5. Receiving networks MAY use the SA objects to apply source-based policy.

RPKI Source Authorization objects are intended to inform local policy decisions rather than to directly affect BGP route selection.

The SOURCE_SELECTIVE Path Attribute is optional, transitive, and summarization-safe.

## Design Rationale {#design-rationale}

This subsection is non-normative.

The SOURCE_SELECTIVE Path Attribute associates RPKI objects (e.g. SPA) with specific BGP route advertisements while preserving BGP semantics. RPKI provides verifiable assertions about which sources are authorized to originate traffic for a given prefix, but it does not define how such assertions are associated with BGP routes. SOURCE_SELECTIVE allows a BGP speaker to reference these holder-signed objects without embedding authorization data directly in BGP.

Attaching the source authorization policy directly to the BGP route advertisement ensures natural fate-sharing between reachability and its associated policy constraints. Because the authorization semantics are bound to the lifecycle of the specific NLRI, any subsequent routing changes automatically apply to the policy without requiring independent out-of-band synchronization mechanisms. This cohesive fate-sharing simplifies state management for downstream routers by tracking reachability and authorization policy as a unified routing primitive.

Unlike BGP Communities, which are applied per AS and reflect operational policy, the SOURCE_SELECTIVE Path Attribute carries references to RPKI objects created and signed by the IP prefix holder. This ensures that the attribute conveys holder-authorized source information, rather than unverified operational intent from intermediate ASes.

Route aggregation can obscure authorization semantics tied to more specific prefixes. By allowing multiple RPKI references to be attached to an aggregated route, the attribute preserves this context that would otherwise be lost.

To prevent unnecessary global propagation, the framework includes a control-plane scoping mechanism. Each Source Authorization sub-TLV carries a Max AS Hops metric that decays at external boundaries, allowing prefix holders to define a strict propagation blast radius.

Conventional access control lists (ACLs) and BGP FlowSpec [RFC8955] filters require resource-intensive multi-field packet classification engines. In contrast, the SOURCE_SELECTIVE framework leverages native longest-prefix-match (LPM) logic. Executing a secondary algorithmic LPM lookup for source validation optimizes router hardware utilization, preserving line-rate 
forwarding performance and minimizing memory overhead at scale.

## Intended Status and Scope {#intended-status-and-scope}

This subsection is non-normative.

This document is intended for the Standards Track because it specifies an interdomain transitive BGP path attribute that allows originators to associate source authorization policy with a route. A Standards Track trajectory provides the predictable code-point allocation and uniform vendor parsing required for safe, consistent propagation across independent administrative domains. 

While the broader framework intersects with other Routing Area architectures, this specific document defines protocol extensions to BGP. Specifying the syntax, encoding, and processing rules of a new BGP attribute, along with its interaction with route summarization, falls within the scope of the Inter-Domain Routing (IDR) working group.

# SOURCE_SELECTIVE Path Attribute {#source-selective-path-attribute}

## Overview {#overview}

The SOURCE_SELECTIVE Path Attribute provides a reference to one or more Source Authorization (SA) objects associated with the advertised NLRI.

## Attribute Properties {#attribute-properties}

* Attribute Type Code: TBD (IANA-assigned)
* Attribute Flags:
  * Optional
  * Transitive
  * Partial: per [RFC4271]
  * Extended Length: as required
* Applicable AFI/SAFI:
  * AFI 1 / SAFI 1
  * AFI 2 / SAFI 1

## Attribute Encoding {#attribute-encoding}

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

## SA-ID TLV Format {#sa-id-tlv-format}

Each SA-ID Field is encoded as a TLV (Type-Length-Value) structure, allowing multiple policy types to coexist and enabling future extensibility. 

The SA-ID TLV defines a common identification framework for Source Authorization objects that are anchored to an IP address prefix. The prefix encoding maps directly to the target network prefix space, enabling routers to index and query their local RPKI cache tables.

### Encoding {#encoding}
~~~~~~~~~~
+------------------------+
| SA Type (TLV Type)     | 1 octet (IANA-assigned)
+------------------------+
| TLV Length             | 2 octets
+------------------------+
| Max AS Hops            | 1 octet
+------------------------+
| Prefix Length          | 1 octet
+------------------------+
| Protected Prefix       | Variable Length
+------------------------+
~~~~~~~~~~

* SA Type (TLV Type): Indicates the type of referenced RPKI Source Authorization (SA) object and IP address family. Example assignments (by IANA):  
  * 0x01 = IPv4 Source Prefix Authorization (SPA-v4)
  * 0x02 = IPv6 Source Prefix Authorization (SPA-v6)
  * 0x03-0xFF = reserved for future types  
* TLV Length: Length, in octets, of the Prefix Length and Protected Prefix fields combined.
* Max AS Hops: Maximum number of Autonomous System (AS) hops this sub-TLV can traverse.
* Prefix Length: Length, in bits, of the Address Prefix.
* Protected Prefix: A variable-length field containing the IP address prefix with trailing zeros up to the next full octet boundary. For IPv4, maximum length is 4 octets. For IPv6, Prefix Length is capped at 64 bits (maximum 8 octets).

### Semantics {#semantics}

The SA-ID TLV Value MUST encode the prefix length and the protected prefix associated with the referenced Source Authorization (SA) object. The IP version of the protected prefix is implicitly determined by the SA Type.

For IPv4 SA Types, the Protected Prefix field MUST be encoded as 4 octets. For IPv6 SA Types, the Protected Prefix field MUST be encoded as 8 octets, representing the 64 most significant bits of the IPv6 address. Bits beyond the first 64 are not represented and are implicitly set to zero.

The SA-ID TLV Value does not encode repository locations, filenames, or Uniform Resource Identifiers (URIs). Resolution of SA-IDs MUST be performed exclusively by exact matching against locally cached Source Authorization PDUs received via the RPKI to Router (RTR) protocol (see Appendix A for an abstract overview of this cache synchronization model).

## Semantics of Multiple SA-ID Value Fields {#semantics-of-multiple-sa-id-value-fields}

Each SA-ID field in the SOURCE_SELECTIVE Path Attribute MUST encode a protected IP address prefix. When multiple SA-ID fields are present within a single attribute, they MUST be evaluated as an open set of independent lookup keys.

Duplicate combinations of SA Type, Prefix Length, and Protected Prefix within the same attribute carry no additional meaning and MUST be ignored by the receiving BGP speaker.

BGP speakers MAY include multiple SA-ID fields for a given NLRI when advertising aggregated or summarized routes. Each individual field preserves the cryptographic lookup mapping for a specific contributing subprefix, ensuring that downstream routers can validate the distinct source constraints applied to different components of the aggregated block.

## Support for Route Summarization {#support-for-route-summarization}

When performing route aggregation or summarization, a BGP speaker SHOULD copy the SA-ID fields from all contributing routes into the SOURCE_SELECTIVE attribute of the new aggregated route. This ensures that source constraints tied to more specific prefixes are not silently discarded during control plane propagation.

If the total length of the combined SA-ID fields exceeds local implementation or hardware constraints, or if the applicability of a specific protected prefix to the broader aggregated block cannot be verified, the aggregating router MAY selectively omit fields.

Implementations SHOULD impose configurable maximum limits on the number of SA-ID fields allowed in a single BGP UPDATE to mitigate resource exhaustion or excessive message sizing.

## Processing Rules {#processing-rules}

BGP speakers receiving the SOURCE_SELECTIVE attribute MUST process it as an optional transitive attribute in accordance with the error-handling procedures in [RFC7606].

* Validation failure of referenced RPKI SA Objects MUST NOT invalidate the route.
* Unsupported BGP speakers MUST propagate the attribute unchanged.
* SA-ID fields in the attribute are logical references and MUST NOT be interpreted as instructions to retrieve objects.
* Retrieval and validation of RPKI data are performed via local caches using existing mechanisms (see Appendix A).
* Validated SA Object data MAY be used to enforce policies restricting IP packet forwarding based on source authorization.
* Resolution of SA-IDs TLV MUST be performed by exact data-field matching of the Protected Prefixes against the local cache.
* SA-ID processing SHOULD be consistent across enforcement points to prevent unintended traffic drops or acceptance of unauthorized traffic.
* TLVs of unknown SA Type MUST be propagated unchanged.

## Data-Plane Enforcement and MTU Handling {#data-plane-enforcement-and-mtu-handling}

When programming forwarding state for a route carrying the SOURCE_SELECTIVE attribute:

* Ingress routers MUST enforce strict (destination, source) matching and discard non-matching traffic, including ICMPv6 error messages (e.g., Type 2 PTB and Type 3 Time Exceeded).
* Implementations MUST NOT install blanket bypass rules for incoming ICMPv6 traffic destined to a protected prefix.
* Because strict filtering prevents classic PMTUD [RFC8201], communicating endpoints SHOULD implement DPLPMTUD [RFC8899], maintain a conservative MTU floor (e.g., 1280 octets), or rely on site edge devices (such as firewalls or CPEs) for TCP MSS clamping.

# Operational Considerations {#operational-considerations}

BGP SOURCE_SELECTIVE Attribute is intended to be incrementally deployable and does not require universal support to be useful.

## Operational Guidance {#operational-guidance}

### Route Processing and Resource Optimization {#route-processing-and-resource-optimization}

Resource Protection: To optimize hardware lookup tables and safeguard SSB-enabled router resources, active implementation of these policies SHOULD be restricted exclusively to ASNs that are explicitly identified. When these policies are activated, local router resource utilization SHOULD be carefully monitored to mitigate the risk of resource exhaustion. The mechanisms to identify ASNs for which Source Prefix policies are to be implemented include administrative configuration, BGP Communities, or Autonomous System Provider Authorization (ASPA) based detection mechanisms. Typically, a network supporting SSB would activate Source Prefix policies for locally originated prefixes, prefixes originated by customer AS networks (as identified via ASPA or eBGP Role Detection [RFC9234]), and optionally the broader customer cone of those networks.

Table Resource Reduction: When implementing Source Prefix Policies, operators MAY use RPKI ROA and ASPA information to eliminate irrelevant Source Prefix Policy entries from allowlists. This reduces table resource consumption by removing unnecessary allowlist entries and strengthens Source Address Validation (SAV), as some packets with spoofed source IP addresses that would otherwise match allowlist entries will be filtered.

Route Aggregation Policies: Aggregation policies MAY include Source Authorization (SA) Identifier Value fields of contributing routes in SOURCE_SELECTIVE Path Attributes whenever feasible.

Aggregation Risks: Operators SHOULD take into account that SOURCE_SELECTIVE Attributes may be omitted by upstream networks when networks not supporting the SOURCE_SELECTIVE Path Attribute perform aggregation.

Inbound Evaluation: When a supporting BGP speaker receives a route containing a SOURCE_SELECTIVE attribute, it MUST evaluate the Max AS Hops field of each contained SA sub-TLV against the length of the accompanying AS_PATH attribute. If the number of AS hops in the AS_PATH attribute is greater than the value specified in Max AS Hops, the sub-TLV MUST be considered expired and ignored.

### Policy Enforcement and Monitoring {#policy-enforcement-and-monitoring}

SAV Integration: Enforcement of SOURCE_SELECTIVE Attribute Source Authorization is most effective when combined with Source Address Validation (SAV).

Policy Consistency: Operators SHOULD ensure consistent validation and policy application across enforcement points.

Traffic Protection: Source Authorization policies MAY include mechanisms to protect traffic from congestion or overload caused by other traffic sharing the same network resources, particularly in scenarios where other traffic classes have increased exposure to overload or denial-of-service attacks.

Telemetry and Diagnostics: Monitoring and telemetry systems SHOULD distinguish between routing reachability and source authorization failures.

Source Selective signaling SHOULD be treated as an input to local policy, not as an unconditional authorization decision.

## Scaling Considerations {#scaling-considerations}

SOURCE_SELECTIVE Attribute is designed to scale in large BGP deployments by offloading most policy data to RPKI objects, carrying only compact references in BGP UPDATE messages.

* Limits per UPDATE: Implementations SHOULD impose configurable limits on the number of SA-ID TLVs per NLRI to prevent excessive BGP UPDATE message sizes and reduce CPU and memory load.
* Aggregation behavior: When aggregating multiple prefixes, SA-ID TLVs MAY be selectively included to maintain authorization semantics while avoiding unnecessary growth of attribute size.
* Propagation control: As a transitive attribute, SOURCE_SELECTIVE will be propagated by default. Operators MAY filter or limit TLVs on peering sessions to reduce unnecessary propagation, similar to practices used for BGP Communities.
* Caching and pre-validation: RPKI caches can be used to pre-validate referenced SA objects, minimizing per-update processing overhead on routers.

By keeping only source IP address prefix references in the BGP attribute, the SOURCE_SELECTIVE design balances security expressiveness with operational scalability, and avoids the scaling challenges historically associated with large per-prefix metadata, such as extensive Communities or Extended Communities usage.

## Policy Enforcement on ASBR Nodes {#policy-enforcement-on-asbr-nodes}

Source Authorization (SA) policies derived from the SOURCE_SELECTIVE attribute SHOULD be enforced on Autonomous System Border Routers (ASBRs) interfacing external domains in the ingress direction.

When an ASBR imports a BGP route carrying the SOURCE_SELECTIVE attribute, it MUST map the referenced SA objects to corresponding ingress data-plane packet validation policies. Interior BGP speakers within the AS MAY propagate the attribute without instantiating local forwarding-plane filters.

## Outbound Propagation Guidelines {#outbound-propagation-guidelines}

To minimize unnecessary attribute propagation across the global internet, operators MAY configure outbound routing policies to manage the SOURCE_SELECTIVE attribute when peering with external networks.

When advertising a route to an eBGP peer assumed not to support the Source-Selective BGP Framework, the outbound policy MAY strip the SOURCE_SELECTIVE attribute if the current AS_PATH length relative to the sub-TLV's Max AS Hops indicates that the policy boundary is nearing expiration.

## Impact on Route Selection {#impact-on-route-selection}

The presence, absence, or content of the SOURCE_SELECTIVE attribute MUST NOT influence the BGP Decision Process described in Section 9 of [RFC4271].

A BGP speaker MUST execute the standard BGP route selection and tie-breaking algorithm without considering the SOURCE_SELECTIVE attribute. The attribute and its referenced Source Authorization (SA) policies are evaluated and instantiated in the forwarding plane only after a route has been selected as the best path.


# Security Considerations {#security-considerations}

The Source Prefix Policies do not prevent source address spoofing on networks that do not implement Source Address Validation (SAV), as described in [RFC2827], [RFC8704], and [RFC3704]. Network operators implementing Source-Selective BGP SHOULD have a solid SAV mechanism in place for the source prefixes included in SSB. Enforcement of Source Prefix Policies will be ineffective in the presence of spoofed source addresses.

Source Prefixes are published in publicly accessible RPKI repositories and may reveal information about communication relationships or traffic patterns. To mitigate these risks, an AS network MAY choose to limit the advertisement or use of Source Prefix Policy-enabled routes to networks that:

* Explicitly support the SOURCE_SELECTIVE Path Attribute and the RPKI SPA Policies,
* Limit Source Prefix Policies Allowlist entries based RPKI ROA and ASPA information, and
* Apply SAV on customer and interconnection interfaces.

Such limitations are optional but improve source-based authorization effectiveness and reduce abuse risk.

Failure to validate Source Prefix Authorization (SPA) objects correctly, or to apply consistent policy across enforcement points, may result in unintended traffic drops or acceptance of unauthorized traffic.

Implementations should validate TLV sizes carried in the SOURCE_SELECTIVE attribute and reject extreme updates.

SOURCE_SELECTIVE attribute relies on RPKI to ensure that only legitimate holders of IP address prefixes can publish Source Authorization (SA) objects. Integrity and authenticity of SA objects depend on correct RPKI certificate issuance, publication, and validation.

## ICMPv6 Bypass Prevention {#icmpv6-bypass-prevention}

Exempting ICMPv6 messages from source-selective validation allows unauthorized third parties to inject arbitrary traffic toward protected prefixes. To prevent data-plane denial-of-service (DDoS) reflection and state-exhaustion attacks, source-selective filtering MUST be applied uniformly across all IP protocols without unauthenticated ICMP exceptions.

## Unsigned Attribute and Integrity Considerations {#unsigned-attribute-and-integrity-considerations}

The SOURCE_SELECTIVE attribute acts strictly as an unsigned lookup pointer and does not carry self-authenticating policy payloads within the BGP UPDATE. To protect against on-path tampering, the receiving BGP speaker MUST validate
any referenced policy identifier against its local cache of cryptographically authenticated Validated SPA Payloads (VSPs).

If an on-path actor alters or injects an unauthorized TLV, the local lookup against the authenticated cache fails, and the router MUST treat the policy as invalid, falling back to default forwarding. If an on-path actor removes the attribute or its TLVs, the route reverts to standard BGP behavior without source-specific filtering. Further threat analysis and trust considerations are detailed in [I-D.braet-idr-source-selective-bgp-framework].

# IANA Considerations {#iana-considerations}

IANA is requested to assign a value to the Source Selective (SOURCE_SELECTIVE) Path Attribute in the "BGP Path Attributes" subregistry under the "Border Gateway Protocol (BGP) Parameters" registry.

IANA is requested to create a new subregistry named "Source-Selective BGP Source Authorization (SA) Types" under the "Border Gateway Protocol (BGP) Parameters" registry group.

Values in this subregistry are to be allocated according to the following registry policies [RFC8126]:

*  0x00: Reserved
*  0x01: IPv4 Source Prefix Authorization (SPA-v4) (This Document)
*  0x02: IPv6 Source Prefix Authorization (SPA-v6) (This Document)
*  0x03 - 0xF0: Expert Review
*  0xF1 - 0xFE: Experimental Use
*  0xFF: Reserved

## Guidance for Designated Experts {#guidance-for-designated-experts}

The Designated Expert (DE) shall assess whether the proposed Source Authorization (SA) Type has a clear, documented operational use case for Source-Selective BGP (SSB) routing, does not duplicate existing functionality, and introduces no operational or technical conflicts with existing SA Types.

To avoid technical conflicts, the DE must verify that the proposed SA Type strictly maintains Address Family Identifier (AFI) separation. An SA Type targeting a specific address family must not encapsulate or process Network Layer Reachability Information (NLRI) matching a different AFI, preventing multi-address-family cross-contamination or overlapping allocation logic.

The documentation must provide sufficient detail to ensure interoperability among independent implementations.

--- back

# Informative Blueprint for RPKI-RTR Protocol Extensions {#informative-blueprint-for-rpki-rtr-protocol-extensions}

## Cache Synchronization Abstract {#cache-synchronization-abstract}

To support the Source-Selective BGP framework, the RPKI-to-Router (RTR) protocol [RFC8210] is extended to transport Validated SPA Payloads (VSPs) from relying party caches to local routers. 

These extensions introduce two new functional PDU types:

1. SPA Announcement PDU: Advertises a valid destination prefix alongside its permitted source prefix boundaries.
2. SPA Withdrawal PDU: Removes a previously signaled SPA profile from the router's local cache.

The exact bit-level wire formats, error codes, and Protocol Data Unit (PDU) structures for these messages are outside the scope of the IDR working group and will be formally specified in a future Standards Track document targeting the SIDROPS working group.

# Acknowledgments {#acknowledgments}
{:unnumbered}

The author would like to thank the individual reviewers from the IETF community for their valuable feedback and contributions during the development of this document.

The design of Source-Selective BGP (SSB) and the specified BGP SOURCE_SELECTIVE Attribute build on decades of work in BGP, RPKI, and secure routing. The author gratefully acknowledges the contributions of the IETF IDR, SIDROPS, and GROW working groups.
