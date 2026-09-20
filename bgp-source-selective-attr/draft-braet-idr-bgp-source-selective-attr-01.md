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
  I-D.braet-sidrops-spa-profile:
    title: "A Profile for Source Prefix Authorizations (SPAs)"
    author:
      ins: K. Braet
      name: Kamiel Braet
      org: Liberty Global Ltd.
    seriesinfo:
      IETF: draft-braet-sidrops-spa-profile
    date: 2026
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
  RFC4360:
  RFC8092:
  RFC8126:
  RFC8210:
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

This document is part of the Source-Selective BGP framework [I-D.braet-idr-source-selective-bgp-framework], which defines an architecture consisting of RPKI SA objects and a BGP Path Attribute used to reference them. The SOURCE_SELECTIVE Path Attribute provides a mechanism to bind BGP reachability information to holder-signed source authorization data.

This document specifies the syntax and protocol procedures for the SOURCE_SELECTIVE path attribute. As specified in {{impact-on-route-selection}}, this attribute does not alter standard BGP route selection.

For a detailed analysis of why existing community mechanisms (e.g., [RFC4360], [RFC8092]) cannot be used for this signaling, see Section 9.1.5 of [I-D.braet-idr-source-selective-bgp-framework].

# Terminology {#terminology}

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in [RFC2119].

* Source Authorization (SA): An RPKI Object created by prefix holders to define sources authorized to originate traffic toward their prefixes or subprefixes. Examples include SPA and SGA RPKI Object types.
* Source Prefix Authorization (SPA): A set of Source IP address prefixes authorized to send packets to a destination prefix published in RPKI as specified in [I-D.braet-sidrops-spa-profile]
* SOURCE_SELECTIVE: The BGP Path Attribute that references one or more RPKI SA objects as specified in this document.
* Source Authorization Identifier (SA-ID): A SOURCE_SELECTIVE sub-TLV field that encapsulates a network prefix structure, serving as a data-plane lookup key to reference a specific validated RPKI SA object within a router's local cache.
* Source Address Validation (SAV): Techniques that prevent packets with spoofed source addresses from entering or traversing a network.
* SPA-v4 and SPA-v6: In this document, the terms SPA-v4 and SPA-v6 are used informatively to refer to IPv4 and IPv6 instantiations of the Source Prefix Authorization (SPA) object, respectively.

# Architecture Overview {#architecture-overview}

BGP SOURCE_SELECTIVE Attribute operates as follows:

1. A prefix holder creates a list of Sources authorized to send packets to the holder's destination prefix or a designated subprefix of that prefix.
2. The list is published as one or more SA Objects. For example Source Prefix Authorization (SPA) Objects.
3. The destination prefix is advertised via BGP.
4. The BGP UPDATE includes the SOURCE_SELECTIVE Path Attribute referencing SA object(s) using one or more Source Authorization Identifier (SA-ID) fields.
5. Receiving networks MAY use the SA objects to apply source-based policy.

RPKI SA objects are intended to inform local policy decisions rather than to directly affect BGP route selection.

## Design Rationale {#design-rationale}

This subsection is non-normative.

The SOURCE_SELECTIVE Path Attribute associates RPKI objects (e.g. SPA) with specific BGP route advertisements while preserving BGP semantics. RPKI provides verifiable assertions about which sources are authorized to originate traffic for a given prefix, but it does not define how such assertions are associated with BGP routes. SOURCE_SELECTIVE allows a BGP speaker to reference these holder-signed objects from BGP route advertisements.

Attaching the source authorization policy directly to the BGP route advertisement ensures fate-sharing between reachability and its associated policy constraints. Because the authorization semantics are bound to the lifecycle of the specific NLRI, any subsequent routing changes automatically apply to the policy without requiring independent out-of-band synchronization mechanisms.

The SOURCE_SELECTIVE Path Attribute carries compact references to Source Authorization objects rather than embedding authorization data directly into BGP UPDATE messages. This separates policy distribution from route advertisement and allows authorization information to be maintained within the RPKI system while only lightweight references are propagated through BGP.

Unlike BGP Communities, which are applied per AS and reflect operational policy, the SOURCE_SELECTIVE Path Attribute carries references to RPKI objects created and signed by the IP prefix holder. This ensures that the attribute conveys holder-authorized source information, rather than unverified operational intent from intermediate ASes.

Route aggregation can obscure authorization semantics tied to more specific prefixes. By allowing multiple RPKI references to be attached to an aggregated route, the attribute preserves this context that would otherwise be lost.

To prevent unnecessary global propagation, the framework includes a control-plane scoping mechanism. Each Source Authorization sub-TLV carries a Max AS Hops value that limits the AS-path scope within which the referenced Source Authorization is considered valid. Supporting BGP speakers evaluate this value against the route's AS_PATH and SHOULD suppress propagation of Source Authorization information when the Max AS Hops limit has been reached.

Conventional access control lists (ACLs) and BGP FlowSpec [RFC8955] policies are typically represented as packet classification rules. SOURCE_SELECTIVE instead expresses authorization using source and destination prefix relationships. This allows implementations to leverage forwarding resources commonly used for prefix lookups, which are typically provisioned at substantially larger scale than policy classification resources.

## Intended Status and Scope {#intended-status-and-scope}

This subsection is non-normative.

This document is intended for the Standards Track because it specifies an interdomain transitive BGP path attribute that allows originators to associate source authorization policy with a route. A Standards Track trajectory provides the predictable code-point allocation and uniform vendor parsing required for safe, consistent propagation across independent administrative domains. 

While the broader framework intersects with other Routing Area architectures, this specific document defines protocol extensions to BGP. Specifying the syntax, encoding, and processing rules of a new BGP attribute, along with its interaction with route summarization, falls within the scope of the Inter-Domain Routing (IDR) working group.

# SOURCE_SELECTIVE Path Attribute {#source-selective-path-attribute}

## Overview {#overview}

The SOURCE_SELECTIVE Path Attribute provides a reference to one or more SA objects associated with the advertised NLRI.

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
* The Number of SA-ID TLVs indicates the total number of TLVs that follow.
* SA-ID TLVs are encoded sequentially, with no padding between fields.

If the total Attribute Length exceeds 255 octets, the Extended Length flag MUST be set and a two-octet Attribute Length field used, as specified in [RFC4271].

## SA-ID TLV Format {#sa-id-tlv-format}

Each SA-ID Field is encoded as a TLV (Type-Length-Value) structure, allowing multiple policy types to coexist and enabling future extensibility. 

The SA-ID TLV defines a common identification framework for SA objects that are anchored to an IP address prefix. The prefix encoding maps directly to the target network prefix space, enabling routers to index and query their local RPKI cache tables.

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
| Protected Prefix       | 4 or 8 octets
+------------------------+
~~~~~~~~~~

* SA Type (TLV Type): Indicates the type of referenced RPKI SA object and IP address family. Example assignments (by IANA):  
  * 0x01 = IPv4 Source Prefix Authorization (SPA-v4)
  * 0x02 = IPv6 Source Prefix Authorization (SPA-v6)
  * 0x03-0xFF = reserved for future types  
* TLV Length: The length, in octets, of the TLV Value field, including the Max AS Hops, Prefix Length, and Protected Prefix fields.
* Max AS Hops: Maximum AS-path distance at which the referenced Source Authorization is considered valid.
* Prefix Length: Length, in bits, of the Address Prefix.
* Protected Prefix: A fixed-length field containing the IP address prefix associated with the referenced SA object. For IPv4 SA Types, the field occupies 4 octets. For IPv6 SA Types, the field occupies 8 octets.

### Semantics {#semantics}

The SA-ID TLV Value MUST encode the prefix length and the protected prefix associated with the referenced SA object. The IP version of the protected prefix is implicitly determined by the SA Type.

For IPv4 SA Types, the Protected Prefix field MUST be encoded as 4 octets. For IPv6 SA Types, the Protected Prefix field MUST be encoded as 8 octets, representing the 64 most significant bits of the IPv6 address. Bits beyond the first 64 are not represented and are implicitly set to zero.

A SOURCE_SELECTIVE attribute MAY contain one or more SA-ID TLVs. An SA-ID applies to an NLRI when the Protected Prefix encoded in the SA-ID is equal to or more specific than the NLRI carried in the UPDATE. SA-ID TLVs that do not correspond to at least one NLRI in the UPDATE MUST be ignored.

## Multiple SA-ID TLVs and Route Aggregation {#multiple-sa-id-tlvs-route-aggregation}

Each SA-ID TLV in the SOURCE_SELECTIVE Path Attribute MUST encode a protected IP address prefix. When multiple SA-ID TLVs are present within a single attribute, they MUST be evaluated as an unordered set of independent Source Authorization references.

Duplicate combinations of SA Type, Prefix Length, and Protected Prefix within the same attribute carry no additional meaning and MUST be ignored by the receiving BGP speaker.

When performing route aggregation or summarization, a BGP speaker SHOULD copy the SA-ID TLVs from all contributing routes into the SOURCE_SELECTIVE attribute of the aggregated route.

If the total length of the combined SA-ID TLVs exceeds local implementation or hardware constraints, or if the applicability of a specific protected prefix to the broader aggregated block cannot be verified, the aggregating router MAY selectively omit fields.

## Processing Rules {#processing-rules}

BGP speakers receiving the SOURCE_SELECTIVE attribute MUST process it in accordance with the error-handling procedures in [RFC7606].

* Validation failure of referenced RPKI SA Objects MUST NOT invalidate the route.
* Unsupported BGP speakers MUST propagate the attribute unchanged.
* SA-ID TVLs in the attribute are logical references and MUST NOT be interpreted as instructions to retrieve objects.
* Retrieval and validation of RPKI data are performed via local caches using existing mechanisms (see Appendix A).
* Validated SA Object data MAY be used to enforce policies restricting IP packet forwarding based on source authorization.
* Resolution of SA-ID TLVs MUST be performed by exact data-field matching of the Protected Prefixes against the local cache Source Authorization PDUs.
* SA-ID processing SHOULD be consistent across enforcement points to prevent unintended traffic drops or acceptance of unauthorized traffic.
* TLVs of unknown SA Type MUST be propagated unchanged.
* An SA-ID TLV whose encoding does not conform to {{sa-id-tlv-format}} is considered malformed.

## Data-Plane Enforcement Considerations {#data-plane-enforcement-considerations}

Implementations MUST NOT treat the IP protocol number alone as sufficient to bypass a configured source-authorization policy. Local policy MAY provide explicitly scoped handling for control and diagnostic traffic. Additional operational considerations are discussed in [I-D.braet-idr-source-selective-bgp-framework].

# Operational Considerations {#operational-considerations}

BGP SOURCE_SELECTIVE Attribute is intended to be incrementally deployable and does not require universal support to be useful.

## Operational Guidance {#operational-guidance}

### Route Processing and Resource Optimization {#route-processing-and-resource-optimization}

Resource Protection: To optimize hardware lookup tables and safeguard SSB-enabled router resources, active implementation of these policies SHOULD be restricted exclusively to ASNs that are explicitly identified. When these policies are activated, local router resource utilization SHOULD be carefully monitored to mitigate the risk of resource exhaustion. The mechanisms to identify ASNs for which SPA (Source Prefix Authorization) policies are to be implemented include administrative configuration, BGP Communities, or Autonomous System Provider Authorization (ASPA) based detection mechanisms. Typically, a network supporting SSB would activate SPA policies for locally originated prefixes, prefixes originated by customer AS networks (as identified via ASPA or eBGP Role Detection [RFC9234]), and optionally the broader customer cone of those networks.

Table Resource Reduction: When implementing SPA Policies, operators MAY use RPKI ROA and ASPA information to eliminate irrelevant SPA Policy entries from allowlists. This reduces table resource consumption by removing unnecessary allowlist entries and strengthens Source Address Validation (SAV), as some packets with spoofed source IP addresses that would otherwise match allowlist entries will be filtered.

Route Aggregation Policies: Aggregation policies MAY include SA-ID TLVs of contributing routes in SOURCE_SELECTIVE Path Attributes whenever feasible.

Aggregation Risks: Operators SHOULD take into account that SOURCE_SELECTIVE Attributes may be omitted by upstream networks when networks not supporting the SOURCE_SELECTIVE Path Attribute perform aggregation.

### Policy Enforcement and Monitoring {#policy-enforcement-and-monitoring}

SAV Integration: Enforcement of SOURCE_SELECTIVE Attribute Source Authorization is most effective when combined with Source Address Validation (SAV).

Traffic Protection: Source Authorization policies MAY include mechanisms to protect traffic from congestion or overload caused by other traffic sharing the same network resources, particularly in scenarios where other traffic classes have increased exposure to overload or denial-of-service attacks.

Telemetry and Diagnostics: Monitoring and telemetry systems SHOULD distinguish between routing reachability and source authorization failures.

Source Selective signaling SHOULD be treated as an input to local policy, not as an unconditional authorization decision.

## Scaling Considerations {#scaling-considerations}

* Limits per UPDATE: Implementations SHOULD impose configurable limits on the number of SA-ID TLVs per NLRI to prevent excessive BGP UPDATE message sizes and reduce CPU and memory load.
* Aggregation behavior: When aggregating multiple prefixes, SA-ID TLVs MAY be selectively included to maintain authorization semantics while avoiding unnecessary growth of attribute size.
* Propagation control: As a transitive attribute, SOURCE_SELECTIVE will be propagated by default. Operators MAY filter or limit TLVs on peering sessions to reduce unnecessary propagation, similar to practices used for BGP Communities.
* Caching and pre-validation: RPKI caches can be used to pre-validate referenced SA objects, minimizing per-update processing overhead on routers.

## Policy Enforcement on ASBR Nodes {#policy-enforcement-on-asbr-nodes}

Source Authorization (SA) policies derived from the SOURCE_SELECTIVE attribute SHOULD be enforced on Autonomous System Border Routers (ASBRs) interfacing external domains in the ingress direction.

When an ASBR imports a BGP route carrying the SOURCE_SELECTIVE attribute for which it is configured to enforce an SA policy, it MUST map the referenced SA objects to corresponding ingress data-plane packet validation policies. Interior BGP speakers within the AS MAY propagate the attribute without instantiating local forwarding-plane filters.

## Outbound Propagation Guidelines {#outbound-propagation-guidelines}

To minimize unnecessary attribute propagation across the global internet, operators MAY configure outbound routing policies to manage the SOURCE_SELECTIVE attribute when peering with external networks.

When advertising a route to an eBGP peer assumed not to support the Source-Selective BGP Framework, the outbound policy MAY strip the SOURCE_SELECTIVE attribute if the current AS_PATH length relative to the sub-TLV's Max AS Hops indicates that the policy boundary is nearing expiration.

## Max AS Hops Evaluation and Propagation {#max-as-hops-evaluation-propagation}

Each SA-ID TLV carries a Max AS Hops value that limits the AS-path scope within which the referenced Source Authorization is valid. Supporting BGP speakers evaluate this value against the route's AS_PATH and SHOULD suppress propagation of Source Authorization information once the Max AS Hops limit has been reached.

### AS Path Distance Calculation

For evaluation of the Max AS Hops field, a supporting BGP speaker derives an Effective AS Path Count from the AS_PATH attribute as follows:
 
* Confederation path segments MUST NOT be counted.
* An AS_SET MUST contribute one hop, regardless of the number of AS numbers contained within the set.
* Within an AS_SEQUENCE segment, each unique AS number MUST contribute one hop.

The resulting value is referred to as the Effective AS Path Count.

### Inbound Evaluation

A receiving BGP speaker MUST compare the Effective AS Path Count against the Max AS Hops value.

If the Effective AS Path Count exceeds the Max AS Hops value, the corresponding SA-ID TLV MUST be considered out of scope and MUST be ignored for local policy evaluation.

### Outbound Propagation

When advertising a route to an eBGP peer, a supporting BGP speaker SHOULD suppress propagation of SA-ID TLVs whose Effective AS Path Count is equal to or greater than the associated Max AS Hops value.

## Impact on Route Selection {#impact-on-route-selection}

The presence, absence, or content of the SOURCE_SELECTIVE attribute MUST NOT influence the BGP Decision Process described in Section 9 of [RFC4271].

A BGP speaker MUST execute the standard BGP route selection and tie-breaking algorithm without considering the SOURCE_SELECTIVE attribute. The attribute and its referenced Source Authorization (SA) policies are evaluated and instantiated in the forwarding plane only after a route has been selected as the best path.


# Security Considerations {#security-considerations}

The Source Prefix Policies do not prevent source address spoofing on networks that do not implement Source Address Validation (SAV), as described in [RFC2827], [RFC8704], and [RFC3704]. Network operators implementing Source-Selective BGP SHOULD have a solid SAV mechanism in place for their referenced source prefixes. Enforcement of Source Prefix Policies will be ineffective in the presence of spoofed source addresses.

Source Prefixes are published in publicly accessible RPKI repositories and may reveal information about communication relationships or traffic patterns. To mitigate these risks, an AS network MAY choose to limit the advertisement or use of Source Prefix Policy-enabled routes to networks that:

* Explicitly support the SOURCE_SELECTIVE Path Attribute and the RPKI SPA Policies,
* Limit Source Prefix Policies Allowlist entries based RPKI ROA and ASPA information, and
* Apply SAV on customer and interconnection interfaces.

Such limitations are optional but improve source-based authorization effectiveness and reduce abuse risk.

Implementations should validate TLV sizes carried in the SOURCE_SELECTIVE attribute and reject extreme updates.

SOURCE_SELECTIVE attribute relies on RPKI to ensure that only legitimate holders of IP address prefixes can publish SA objects. Integrity and authenticity of SA objects depend on correct RPKI certificate issuance, publication, and validation.

## Unsigned Attribute and Integrity Considerations {#unsigned-attribute-and-integrity-considerations}

The SOURCE_SELECTIVE attribute acts strictly as an unsigned lookup pointer and does not carry self-authenticating policy payloads within the BGP UPDATE. To protect against on-path tampering, the receiving BGP speaker MUST validate any referenced policy identifier against its local cache of cryptographically authenticated Validated SPA Payloads (VSPs).

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

# Change Log {#change-log}

*RFC EDITOR: Please remove this section before publication.*

Changes from draft-braet-idr-bgp-source-selective-attr-00 to -01:

* Fully updated the IANA Considerations section based on direct IANA email feedback.
* Updated author affiliation company name to Liberty Global.
* Introduced a "Max AS Hops" sub-TLV field based on mailing list feedback. This updated the Design Rationale, Encoding, Semantics, Support for Route Summarization, Route Processing, and Resource Optimization sections, and added the "Max AS Hops Evaluation and Propagation" section.
* Added "Data-Plane Enforcement Considerations" section with reference to Source-Selective BGP Framework to address path MTU discovery concerns.
* Replaced the "Hardware Optimization" section with a "Resource Protection" section to improve guidelines for explicitly controlling router resource usage during source policy implementation.
* Updated the Introduction with a reference to the Framework document explaining why BGP Communities are not used.
* Added a "Policy Enforcement on ASBR Nodes" section to specify exactly where source authorization policies should be enforced.
* Added an "Unsigned Attribute and Integrity Considerations" section to the Security Considerations section.
* Added an "Impact on Route Selection" section to Section 5 (Operational Guidance) to normatively state that BGP route selection is not influenced.
* Updated Security Considerations to state that Network Operations SHOULD implement SAV for source prefixes included in SSB.
* Revised the first paragraph of Section 1 to explicitly clarify that this mechanism only offers IP reachability control.
* Added text to the Design Rationale highlighting the resource consumption differences between packet filters and SSB's second lookup.
* Added a non-normative "Intended Status and Scope" section.
* Merged sections "Semantics of Multiple SA-ID Value Fields" and "Support for Route Summarization" into "Multiple SA-ID TLVs and Route Aggregation".

# Acknowledgments {#acknowledgments}
{:unnumbered}

The author would like to thank the individual reviewers from the IETF community for their valuable feedback and contributions during the development of this document.

The design of Source-Selective BGP (SSB) and the specified BGP SOURCE_SELECTIVE Attribute build on decades of work in BGP, RPKI, and secure routing. The author gratefully acknowledges the contributions of the IETF IDR, SIDROPS, and GROW working groups.

