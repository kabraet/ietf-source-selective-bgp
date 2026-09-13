---
title: Source-Selective BGP Framework
abbrev: SSB
docname: draft-braet-idr-source-selective-bgp-framework-00
date: 2026-06-16
category: info

ipr: trust200902
area: Routing
keyword: Internet-Draft
workgroup: idr

stand_alone: true
pi: [toc, sortrefs, symrefs]
submissiontype: IETF

author:
  ins: K. Braet
  name: Kamiel Braet
  organization: Liberty Global Ltd.
  email: kabraet@libertyglobal.com
  country: Netherlands

normative:
  I-D.braet-idr-bgp-source-selective-attr:
    title: "BGP Source-Selective Attribute"
    author:
      ins: K. Braet
      name: Kamiel Braet
      org: Liberty Global Ltd.
    seriesinfo:
      Internet-Draft: draft-braet-idr-bgp-source-selective-attr
    date: 2026
  I-D.braet-sidrops-spa-profile:
    title: "A Profile for Source Prefix Authorizations (SPAs)"
    author:
      ins: K. Braet
      name: Kamiel Braet
      org: Liberty Global Ltd.
    seriesinfo:
      Internet-Draft: draft-braet-sidrops-spa-profile
    date: 2026
  RFC4271:
  RFC6480:

informative:
  RFC2622:
  RFC2827:
  RFC3704:
  RFC5635:
  RFC5652:
  RFC6482:
  RFC8210:
  RFC8782:
  RFC8955:

--- abstract

The Border Gateway Protocol (BGP) routes traffic solely based on destination IP prefixes. Source Selective BGP (SSB) introduces an architecture combining BGP and Resource Public Key Infrastructure (RPKI) extensions, which allows prefix holders to cryptographically signal RPKI source authorization policies for their advertised reachability.

SSB distributes references to these policies via a new BGP path attribute, allowing routing systems to incorporate source-based constraints into local forwarding policies. Crucially, SSB does not define a source address validation mechanism, mandate packet filtering behavior, or alter fundamental destination-based routing; interpretation remains a matter of local operator policy. This document provides the overall architectural context and deployment rationale for the SSB protocol suite.

--- middle

# Introduction

The Border Gateway Protocol (BGP) [RFC4271] routes packets based on their destination IP address.  A BGP router selects the best path to a destination prefix and forwards all traffic destined to that prefix along the chosen path, regardless of the traffic's source address.
This destination-only routing model has been fundamental to the Internet's success, enabling simplicity, scalability, and stability. However, it creates challenges in scenarios where networks need to control which sources are permitted to send traffic to a destination.

Examples of these challenges include:

*  DDoS mitigation: During volumetric DDoS attacks, such as carpet bombing vectors, a target network cannot selectively admit trusted traffic at its boundary if upstream interdomain transit links are already overwhelmed. Because traffic filtering occurs post-transit, the incoming access link undergoes total capacity exhaustion, rendering local edge mitigation mechanisms completely ineffective.
*  Extranet connectivity: Organizations cannot advertise IP prefixes that are reachable only for specific partners.

Source Selective BGP (SSB) addresses these limitations by enabling prefix holders to signal authorization policies indicating which source prefixes are permitted to use their advertised reachability. SSB builds on the Resource Public Key Infrastructure (RPKI) [RFC6480] to provide cryptographically verifiable authorization data that can be distributed and used by routing systems.
The mechanism is intended to extend routing policy signaling and does not modify the fundamental destination-based forwarding model of BGP. Authorization information is carried as an input to local routing and forwarding policy, and the interpretation of this information is left to the receiving operator.

This document introduces SSB, including:

*  Motivation (Section 3)
*  Architectural overview and components (Sections 4 and 5)
*  Use cases (Section 6)
*  Deployment, operational, and specification considerations (Sections 7, 8, and 9)
*  Comparison with existing mechanisms (Section 10)
*  Security analysis (Section 11)

The normative protocol specifications for SSB are defined in two separate Standards Track documents:

*  BGP SOURCE_SELECTIVE Path Attribute [I-D.braet-idr-bgp-source-selective-attr]
*  RPKI Source Prefix Authorization objects [I-D.braet-sidrops-spa-profile]

Note: The underlying RPKI-to-Router (RTR) protocol PDU wire formats for delivering this payload are handled informatively via Appendix A of [I-D.braet-idr-bgp-source-selective-attr].

This document is informational and does not define protocol mechanisms. It is intended to provide architectural context and deployment rationale for the SSB protocol suite.

# Terminology

* Source-Selective BGP (SSB): A BGP, RPKI and RTR extension to allow prefix holders to express intent about which sources are authorized to send traffic to those prefixes.
* Source Authorization (SA): An RPKI Object created by prefix holders to define sources authorized to originate traffic toward their prefix or sub-prefix. For example an SPA RPKI Object type.
* Source Authorization Identifier (SA-ID): Source Authorization Identifier, a compact reference to an SPA object carried in the BGP SOURCE_SELECTIVE path attribute. 
* Source Prefix Authorization (SPA): A set of Source IP address prefixes authorized to send packets to a destination prefix published in RPKI as specified in [I-D.braet-sidrops-spa-profile]
* Source-Selective (SOURCE_SELECTIVE): The BGP Path Attribute that references one or more RPKI Source Authorization (SA) objects as specified in [I-D.braet-bgp-source-selective-attr.
* RPKI-to-Router protocol (RTR): A protocol that delivers Validated ROA Payloads (VRPs) from a relying party cache to routers, enabling BGP route validation without the router needing to process complex cryptography [RFC8210].
* Validated SPA Payload (VSP): Router RPKI Cache holding Validated SPA Payload retrieved via RTR.
* Destination Prefix: The IP prefix being advertised in NLRI field of a BGP UPDATE message.
* Authorized Source Prefix: A source IP prefix that is authorized by an SPA to send traffic to a destination prefix.

The terms "AS" (Autonomous System), "BGP speaker", "NLRI" (Network Layer Reachability Information), and "Path Attribute" are used as defined in [RFC4271].

# Motivation

## Limitations of Destination-Only Routing

BGP's destination-only forwarding model treats all traffic equally, regardless of its source. Once a route to a destination prefix is selected, the router forwards all packets destined to that prefix along the chosen path.

This creates several challenges:

* Networks cannot differentiate between legitimate traffic from trusted sources and malicious traffic from attackers.
* Service providers cannot offer connectivity that is selectively available only to specific customer populations.
* Enterprises cannot advertise internal services that should be reachable only from business partners or branch offices.

Existing workarounds, such as access control lists (ACLs), firewall rules, and VPN overlays, operate above the IP routing layer or on the receiving end only and cannot influence Internet forwarding. These mechanisms:

* Require traffic to traverse the network before being filtered, consuming bandwidth and resources.
* Cannot prevent upstream networks from forwarding unwanted traffic.
* Lack cryptographic verifiability and rely on manual configuration.
* Do not integrate with the Internet's global routing system.

## DDoS and Security Challenges

Distributed Denial of Service (DDoS) attacks exploit the destination-only routing model by sending large volumes of malicious traffic that cannot be distinguished from legitimate traffic at the routing layer.

Current DDoS mitigation strategies include:

* Remotely Triggered Black Hole (RTBH) filtering [RFC5635], which discards all traffic to a destination, including legitimate traffic.
* BGP FlowSpec [RFC8955], which requires per-flow filter distribution, does not provide cryptographic authorization by the holder of the IP addresses on the receiving end.
* Scrubbing centers, which introduce latency, cost, and potential privacy concerns.
* DDoS Open Threat Signaling (DOTS) [RFC8782], which provides a bilateral framework to reactively signal mitigation requests upstream, but depends on pre-existing provider relationships and lacks a mechanism for global, multi-hop cryptographic source authorization.

None of these approaches enable a network at the receiving end to cryptographically signal "accept traffic to this destination only from these authorized sources" in a way that upstream networks can validate and enforce.

## Business Connectivity Requirements

Enterprises and service providers require selective reachability for business connectivity:

*  B2B Extranet Services: A manufacturer may want its ordering system reachable only from authorized supplier networks, not from the full Internet.
*  SD-WAN Underlay Protection: An SD-WAN device should be reachable only from the enterprise's own branch locations, not from arbitrary Internet sources.
*  Cloud Service Interconnection: A cloud customer may want specific workloads reachable only from their on-premises networks or approved partners.

Current solutions rely on overlay technologies (IPsec VPNs, MPLS L3VPNs, SD-WAN) or manual ACL configuration. These approaches:

*  Require bilateral coordination and manual configuration.
*  Do not leverage the global BGP routing system.
*  Cannot be cryptographically verified by intermediate networks.
*  Increase operational complexity and reduce agility.

## Source-Constrained Reachability Model

Some operational models require that reachability to specific destination prefixes be constrained based on the set of permitted source networks. Examples include controlled interconnection between organizations, protection of infrastructure endpoints, and reduction of unwanted traffic from unknown sources.

Existing Internet routing mechanisms do not provide a standardized way for prefix holders to signal such source-specific reachability constraints to other networks. As a result, operators rely on locally configured filtering, overlay mechanisms, or application-layer controls.

Source Selective BGP (SSB) enables prefix holders to publish authorization information indicating which source prefixes are permitted to use their advertised reachability, and to signal the applicability of this information using BGP.

This approach allows routing systems to incorporate source-based policy inputs into local decision-making processes, where supported. The mechanism is compatible with existing destination-based routing and does not require changes to endpoint behavior.

The use of source-constrained reachability policies is intended to support operational use cases where tighter control over permitted traffic sources is desirable. The interpretation and enforcement of these policies remain a matter of local operator configuration.

# Overview of Source-Selective BGP

## Core Concept

Source-Selective BGP enables a prefix holder to cryptographically declare: "Traffic to my destination prefix D should be accepted only if it originates from source prefixes S1, S2, ..., Sn."

This authorization is expressed as a Source Prefix Authorization (SPA) object, signed using the RPKI and published in the global RPKI repository system.  The SPA is then referenced in BGP route advertisements using a new SOURCE_SELECTIVE path attribute.

Routers that support SSB may:

1. Fetch and validate SPA objects from the RPKI repository using the Relying Party Validator.
2. Process BGP UPDATE messages containing SOURCE_SELECTIVE attributes.
3. Install data plane filters that permit only authorized source prefixes to reach the advertised destination.

Routers that do not support SSB can ignore the SOURCE_SELECTIVE attribute and continue to forward traffic using destination-only routing, enabling incremental deployment.

## How SSB Works

The SSB workflow involves four main steps:

Step 1: SPA Creation and Publication

The prefix holder (e.g., an enterprise) uses their RPKI resource certificate to sign an SPA object that specifies:

* The destination prefix or sub-prefix being protected (e.g., 2001:db8:2016:1f00::/56)
* A list of authorized source prefixes (e.g., 3fff:10::/32, 3fff:20::/32)
* A unique SPA object name derived from the destination prefix or destination sub-prefix being protected

The SPA (e.g. 2001.db8.2016.1f00-56.spa) is published in the global RPKI repository, where it can be fetched and validated by any network operator.

Step 2: BGP Route Advertisement with SOURCE_SELECTIVE Attribute

When advertising the destination prefix in BGP, the origin AS (or an upstream AS) includes a SOURCE_SELECTIVE path attribute in the UPDATE message. This attribute contains one or more SA-IDs that reference the published SPA objects using the destination prefix or destination sub-prefix.

Example:

~~~~~~~~~~
UPDATE message for 2001:db8::/32
Path Attributes:
  ORIGIN: IGP
  AS_PATH: 64496 64497
  SOURCE_SELECTIVE:
    SA-ID: 2001:db8:2016:1f00::/56
~~~~~~~~~~

Step 3: SPA Retrieval and Validation

Routers that receive the UPDATE message extract the SA-ID from the SOURCE_SELECTIVE attribute and retrieve the corresponding SPA object content from the RPKI Validator typically via the RPKI-to-Router protocol.

The RPKI Validator validates:

* The cryptographic signature on the SPA using the RPKI trust anchor.
* That the signing certificate covers the destination prefix.
* That the SPA has not expired.

Following successful validation, the RTR server delivers the VSP (Validated SPA Payload) contents to SSB routers.

Step 4: Data Plane Filter Installation

Once the SPA policy is validated and retrieved from the VSP cache, the router installs a data plane filter (SPA filter) that permits traffic to the destination prefix only from the authorized source prefixes listed in the SPA.

Traffic from unauthorized sources is dropped at ingress, before being forwarded into the network. Example filter logic:

~~~~~~~~~~
IF destination == 2001:db8:2016:1f00::/56 THEN
  IF source IN {3fff:10::/32, 3fff:20::/32} THEN
    FORWARD
  ELSE
    DROP
  END IF
END IF
~~~~~~~~~~

# Architecture and Components

SSB consists of three main technical components, each specified in a separate Standards Track document:

1. RPKI Source Prefix Authorization (SPA) objects
2. BGP SOURCE_SELECTIVE Path Attribute
3. RPKI-to-Router (RTR) Protocol extensions for SPA distribution

## RPKI Source Prefix Authorization (SPA)

An SPA is a digitally signed object, like a Route Origin Authorization (ROA) [RFC6482], that binds a destination prefix to a set of authorized source prefixes.

SPA structure (defined in [I-D.braet-sidrops-spa-profile]) conceptually compasses:

* Version: SPA format version
* Protected Prefix: The destination prefix for which sources are being authorized
* Source Prefix List: One or more authorized source prefixes
* Validity Period: Not Before / Not After timestamps
* Signature: Cryptographic signature using the prefix holder's RPKI certificate

SPAs are encoded as CMS-signed objects [RFC5652] and published in the RPKI repository system using the same distribution mechanisms as ROAs, certificates, and manifests.

Key properties:

* Cryptographically verifiable: Any party can validate the signature using the RPKI trust hierarchy.
* Destination prefix authorization: The signing certificate must cover the destination prefix.
* Global discoverability: SPAs are published in the global RPKI repository and can be fetched by any network.
* Revocable: SPAs can be expired or revoked by publishing updated manifests.

## BGP SOURCE_SELECTIVE Path Attribute

The SOURCE_SELECTIVE path attribute is an optional transitive BGP path attribute that carries references (SA-IDs) to one or more SPA objects.

Attribute structure (defined in [I-D.braet-idr-bgp-source-selective-attr]):

* Attribute Type Code: TBD (to be assigned by IANA)
* Attribute Flags: Optional, Transitive
* Attribute Length: Variable
* SA-ID List: One or more SA-IDs (References to SPAs)

The attribute is optional transitive, meaning:

* Routers that understand SSB process the attribute and may install SPA filters.
* Routers that do not understand SSB propagate the attribute unchanged, enabling incremental deployment.

Multiple SA-IDs can be included to reference multiple SPAs, enabling multiple source authorization policies for a single aggregate prefix advertisement (e.g., authorizing different source sets for different Destination prefixes or different Source Authorization types).

## RPKI-to-Router Protocol Extensions

The RPKI-to-Router (RTR) protocol [RFC8210] is extended to deliver Validated SPA Payloads (VSPs) from validators to routers. This avoids requiring routers to parse complex cryptography directly.

These extensions support the addition and withdrawal of both IPv4 and IPv6 permitted source prefix filters. The informative wire format and lookup models are detailed in Appendix A of [I-D.braet-idr-bgp-source-selective-attr]. A formal protocol specification will be introduced at a later stage.

## Data Flow

The complete SSB data flow:

1. Prefix Holder: Creates and signs SPA, publishes to RPKI repository.
2. RPKI Validator (e.g., Routinator, FORT): Fetches SPA from repository, validates signature and certificate chain.
3. Origin AS: Advertises destination prefix in BGP UPDATE with SOURCE_SELECTIVE attribute containing SA-ID.
4. Transit/Peer AS Routers:
    1. The router receives BGP UPDATE with SOURCE_SELECTIVE attribute.
    2. The router extracts Destination Prefix from attribute. Limiting this check to local and customer BGP routes reduces router resource utilization.
    3. The router queries local RPKI cache (retrieved via RTR protocol) for SPA matching Destination Prefix.
    4. The router retrieves SPA data (destination prefix, source prefix list).
    5. The router validates that destination prefix in SPA matches or is a subset of NLRI in UPDATE.
    6. The router installs data plane SPA filter: permit traffic to destination only from authorized sources.
5. Data Plane: Ingress router applies SPA filter; drops traffic from unauthorized sources.

# Use Cases

## Reliable Cloud Connectivity

Problem: An enterprise connects to a cloud provider (e.g., AWS, Azure, GCP) and wants to ensure that certain cloud-hosted services are reachable only from the enterprise's own networks and vice versa, not from the public Internet.

Traditional approach: Configure cloud firewall rules or security groups to permit traffic only between the enterprise's source IP ranges and the Cloud-hosted service IP ranges. However, this filtering occurs at the cloud perimeter and enterprise firewall. Unauthorized traffic has already traversed the Internet to the enterprise network and services potentially overloading network resources.

SSB solution:

* The cloud provider publishes an SPA authorizing only the enterprise's source prefixes.
* The enterprise publishes an SPA authorizing only the cloud source prefixes.
* The cloud provider and enterprise advertise their prefixes in BGP with a SOURCE_SELECTIVE attribute referencing the SPAs.
* Upstream ISPs that support SSB install SPA filters, dropping unauthorized traffic before it reaches the cloud provider's and enterprise's networks.
* DDoS attacks and unauthorized access attempts are filtered at Internet edge routers, reducing load on the cloud and enterprise infrastructure.

Benefits:

* Reduced attack surface: Unwanted traffic is dropped at the network edge.
* Operational Cost Savings: Minimizes ingress bandwidth fees and prevents DDoS attacks from triggering expensive cloud auto-scaling mechanisms.
* Improved security posture: Cryptographically validate access control at the routing layer.
* Increased availability of Cloud services: Connectivity protected against DDoS attacks.

## SD-WAN Underlay Protection

Problem: An SD-WAN deployment uses the public Internet as an underlay. SD-WAN infrastructure endpoints are Internet-reachable and vulnerable to reconnaissance, vulnerability scanning, and DDoS attacks.

Traditional approach: Deploy the SD-WAN infrastructure behind firewalls or VPN concentrators or use cloud-based DDoS scrubbing services. These add cost, latency, and complexity.

SSB solution:

* The enterprise publishes SPAs authorizing only its own branch office prefixes to reach the SD-WAN controller and SW-WAN edge devices.
* The prefixes for SD-WAN infrastructure are advertised in BGP with SOURCE_SELECTIVE attributes.
* ISPs supporting SSB install SPA filters, ensuring only authorized branch locations can send traffic to SD-WAN endpoints. 

Benefits:

* Protection against Internet-wide attacks: Unauthorized sources cannot reach SD-WAN infrastructure.
* Simplified security architecture: No need for complex firewall rules or scrubbing services.
* Concealed infrastructure footprint: Prevents public Internet reconnaissance, port scanning, and vulnerability discovery against underlay endpoints.
* Increased availability underlay network: Unauthorized sources cannot overload underlay transport.

## Business-to-Business Extranet Connectivity

Problem: A manufacturer operates an ordering system that should be reachable only from authorized supplier networks. Exposing this system on the public Internet creates security risks; using MPLS VPNs with Network-to-Network Interfaces (NNIs) for each supplier adds operational overhead.

Traditional approach: Deploy VPNs or MPLS L3VPNs for each supplier or use application-layer authentication and firewall rules.

SSB solution:

* The manufacturer publishes an SPA authorizing source prefixes belonging to approved suppliers.
* The manufacturer advertises the ordering system prefix in BGP with a SOURCE_SELECTIVE attribute.
* Transit ISPs install SPA filters, allowing only authorized suppliers to reach the ordering system.
* New suppliers can be onboarded by issuing an updated SPA profile without requiring extending a MPLS VPN service with NNIs.

Benefits:

* Dynamic, cryptographically authorized access control: No bilateral VPN setup required.
* Reduced operational complexity: Centralized authorization via RPKI.
* Scalable Partner Onboarding: Enables rapid supplier integration via simple routing policy updates.

## DDoS Mitigation and Traffic Engineering

Problem: Distributed Denial of Service (DDoS) attacks overwhelm destination networks with volumetric traffic. Existing control-plane mitigation techniques, such as Remotely Triggered Black Hole (RTBH) routing or third-party traffic redirection, require reactive implementation after an attack is detected. This introduces a propagation delay during which the attack traffic reaches the destination network. Furthermore, third-party redirection services operate without intrinsic knowledge of the destination's specific connectivity requirements, while RTBH indiscriminately discards all traffic destined to the target IP, resulting in complete service disruption for legitimate users.

SSB solution:

* The prefix holder publishes an SPA specifying authorized source prefixes (e.g., CDN edges or trusted partners) based on its network requirements.
* The destination network advertises the destination prefix in BGP with the SOURCE_SELECTIVE attribute.
* The destination network can apply this attribute exclusively to a more-specific sub-prefix if only a part of the prefix needs protection.
* Supporting upstream networks match traffic against the SPA filter at ingress, dropping traffic from unlisted sources.

Benefits:

* Pre-enforced Filtering: Eliminates the propagation delay associated with reactive mitigation by maintaining an active ingress filter profile.
* Autonomous Traffic Control: Relies on data provided directly by the prefix holder, removing dependence on external traffic classification policies.
* Granular Preservation: Limits traffic drops to unauthorized sources, preventing the total service disruption caused by destination-based black-holing.
* Cryptographically Authorized Intent: Verifies the source-filter policy through the RPKI trust anchor before installation.

# Deployment Considerations

## Incremental Deployment

* The SOURCE_SELECTIVE attribute is optional transitive, routers that do not understand SSB will propagate it unchanged.
* Networks that support SSB gain the ability to enforce source-based filtering; networks that do not support it continue to operate with destination-only routing.
* Prefix holders can begin publishing SPAs and advertising routes with SOURCE_SELECTIVE attributes immediately, even if only some ASes support enforcement.
* As more networks deploy SSB, the security and filtering benefits increase, creating a positive deployment incentive.

Early adopters will likely include:

* ISPs offering differentiated security services to customers
* Cloud and content providers seeking to reduce DDoS exposure
* Large enterprises with strong security requirements

## Provider-Aggregatable (PA) Address Space

Challenge: Many enterprises use Provider-Aggregatable (PA) address space allocated by their ISP. These enterprises do not hold RPKI certificates for PA space and cannot sign SPAs.

Solutions:

* ISP delegation: The ISP can delegate a resource certificate to the enterprise customer, allowing them to sign SPAs for their PA prefixes.
* ISP as SPA publisher: The ISP publishes SPAs on behalf of customers as a managed service.
* Migration to Provider Independent (PI) space: Enterprises that require SSB may choose to obtain PI address space, giving them direct control over RPKI certificates and SPA publication.

## Route Aggregation

Challenge: BGP route aggregation may cause a more-specific route with a SOURCE_SELECTIVE attribute to be aggregated into a less-specific route without the attribute, breaking SSB enforcement.

Solutions:

* Aggregate routes can carry a SOURCE_SELECTIVE attribute with a list of Source Authorization Identifiers covering for more-specific prefixes.
* Routers may include Source Authorization Identifiers of contributing routes in the aggregate route advertisement.

## Brownfield Deployment

SSB is designed to work in existing ("brownfield") networks without requiring forklift upgrades:

* No changes to existing BGP speakers: Routers that do not support SSB simply ignore the SOURCE_SELECTIVE attribute.
* Router software upgrades. SSB requires software support for:
    * Processing the SOURCE_SELECTIVE path attribute
    * Fetching SPA objects via RTR protocol
    * Installing data plane SPA filters
* SPA publication tools: Prefix holders need tools to create, sign, and publish SPA objects, similar to existing ROA management tools.
* RPKI infrastructure: 
    * Risk: Standard specifications lack clear forward compatibility rules, legacy validators encountering unrecognized file formats may reject the entire parent Certificate Authority repository.
    * Mitigation: To prevent these cascading routing dropouts, the new object type must be tested in isolated testbeds and phased into production only after ensuring the global network has upgraded to fault-tolerant validator versions.
    * Precedent: Operational rollouts for objects like Autonomous System Provider Authorizations (ASPA) have successfully conditioned the modern validation ecosystem to safely isolate and ignore un-implemented profile types by default.

# Operational Considerations

## Scaling SPA Filters

Question: How many SPA filters can a router support?

Considerations:

* Data plane capacity: Modern routers support hundreds of thousands of ACL entries; SPA filters are conceptually similar.
* Control plane overhead: Routers must fetch and validate SPAs via RTR protocol; this is comparable to ROA processing.
* Memory: SPA filters consume memory for source prefix lists and destination prefix state.

Mitigation strategies:

* Selective SPA enforcement: Routers can choose to enforce SPAs only for prefixes that are ASN local or advertised by customers.
* Hardware offload: Data plane filtering can be implemented in ASICs or FPGAs for line-rate performance.
* Hierarchical filtering: Edge routers enforce SPAs; core routers may rely on edge enforcement and avoid installing SPA filters.

SSB is not intended for universal enforcement across the default-free zone; operators can and are expected to scope enforcement to prefixes of interest.

## SPA Lifecycle Management

SPA objects have a lifecycle like ROAs:

* Creation: Prefix holder generates and signs SPA using RPKI tooling.
* Publication: SPA is published to RPKI repository and propagated via RPKI sync protocol.
* Validation: RPKI validators fetch, validate, and distribute SPA via RTR protocol.
* Expiration: SPAs include a validity period (Not Before / Not After timestamps). Expired SPAs are automatically invalidated.
* Revocation: SPAs can be revoked by removing them from the manifest or by publishing updated manifests with incremented serial numbers.
* Updates: To add or remove authorized source prefixes, the prefix holder publishes a new SPA with an updated source prefix list.

Best practices:

* Set reasonable validity periods (e.g., 30-90 days) to limit the impact of compromise while minimizing management overhead.
* Automate SPA renewal to avoid accidental expiration. 
* Monitor SPA validation status and alert on failures.

## Monitoring and Troubleshooting

Operators deploying SSB should monitor:

* SPA publication status: Are SPAs successfully published to the RPKI repository?
* SPA validation status: Are routers successfully fetching and validating SPAs?
* SPA filter installation: Are data plane filters correctly installed for advertised prefixes?
* Traffic drops: Are legitimate traffic flows being inadvertently dropped due to misconfigured SPAs?

Troubleshooting tools:

* RPKI validation reports: Show which SPAs are valid, invalid, or missing.
* BGP route monitoring: Verify that SOURCE_SELECTIVE attributes are correctly propagated.
* SPA Destination Prefix match monitoring: Verify that BGP advertised Source Authorization policies are successfully matched in Validated SPA Payload (VSP) cache.
* SPA filter table: Table off all implemented SPA policies and associated BGP route.
* SPA filter logs: Log traffic drops due to SPA enforcement to identify misconfigurations or attacks.
* Test traffic: Send test packets from authorized and unauthorized sources to verify SPA enforcement.

# Specification Considerations

This section outlines key architectural considerations for Source Selective BGP (SSB), with emphasis on the role of the BGP SOURCE_SELECTIVE Path Attribute and its interaction with RPKI-based Source Prefix Authorizations (SPAs).

## Role of the BGP SOURCE_SELECTIVE Path Attribute

While SPAs carry the cryptographically signed Source Authorization policy, explicit signaling in the BGP control plane is required for scalable and operable deployment.

### Controlled Enforcement Scope

SSB allows operators to limit Source Authorization processing and enforcement to operationally relevant routes, such as those originated locally or learned from customer ASNs. The SOURCE_SELECTIVE Path Attribute enables routers to selectively process such routes, avoiding unnecessary control plane and data plane overhead.

### Separation of Authorization and Routing

SSB maintains a clear separation of concerns:

* RPKI provides cryptographically verifiable Source Authorization via SPAs.
* BGP distributes reachability information and signals the applicability of Source Authorization using the SOURCE_SELECTIVE Path Attribute.

This mirrors the existing ROA-based origin validation model and preserves the established roles of RPKI and BGP.

### Explicit and Observable Failure Modes

The combination of SOURCE_SELECTIVE signaling and SPAs creates a clear two-step validation model. If a route is advertised with a SOURCE_SELECTIVE attribute but no corresponding valid SPA is available, the condition is immediately observable. This avoids silent policy mismatches and simplifies operational diagnostics.

### Operational Visibility

Explicit control-plane signaling allows operators to correlate traffic drops with BGP route advertisements and Source Authorization intent. This improves troubleshooting by clearly distinguishing authorization-related drops from routing or forwarding failures.

### Limitations of Alternative Signaling Mechanisms

While BGP Large Communities could carry references to Source Authorization information, such communities are frequently modified or discarded during route aggregation. In contrast, the optional transitive SOURCE_SELECTIVE Path Attribute is preserved across propagation and aggregation, ensuring that Source Authorization intent is not lost.

# Relationship to Existing Mechanisms

## BGP FlowSpec

BGP FlowSpec [RFC8955] allows networks to distribute traffic flow specifications (filters) via BGP. FlowSpec can match on source prefix, destination prefix, ports, protocols, and other fields, and can apply actions such as rate-limiting or dropping.

Differences from SSB:

* Scope: FlowSpec distributes arbitrary filters that can be generated by any entity; SSB specifically binds authorized sources to destinations by the holder of the destination IP addresses.
* Cryptographic authorization: SSB uses RPKI-signed SPAs created by the holder of the destination IP addresses.
* Deployment model: FlowSpec is typically used within a single AS or between trusted ASes; SSB is designed for global Internet deployment.
* Semantics: FlowSpec filters are often reactive (e.g., installed during an attack); SSB authorizations are proactive and policy-driven.

SSB and FlowSpec can be complementary: FlowSpec can provide fine-grained filtering, while SSB provides cryptographically verifiable source authorization.

## RPKI Route Origin Authorization (ROA)

A Route Origin Authorization (ROA) [RFC6482] authorizes an AS to originate a destination prefix. ROAs enable destination prefix validation but do not address source prefixes.

Relationship to SSB:

* SPAs and ROAs use the same RPKI infrastructure (certificates, repositories, validators).
* A prefix holder can publish both ROAs (to authorize origin ASes) and SPAs (to authorize source prefixes).
* ROAs validate "who can announce this prefix"; SPAs validate "who can send traffic to this prefix."

Both mechanisms are complementary and can be deployed together.

## Remotely Triggered Black Hole (RTBH) Filtering

RTBH [RFC5635] allows a network to remotely trigger upstream routers to drop all traffic destined to a specific prefix, typically used for DDoS mitigation.

Differences from SSB:

* Granularity: RTBH drops all traffic; SSB allows selective filtering based on source.
* Use case: RTBH is a last-resort defence; SSB is a proactive access control mechanism.
* Authorization: RTBH relies on trust between ASes; SSB uses cryptographic authorization.

SSB provides a more flexible alternative to RTBH by allowing networks to block attack traffic while continuing to accept legitimate traffic from authorized sources.

## Internet Routing Registry (IRR) and RPSL

The Internet Routing Registry (IRR) and Routing Policy Specification Language (RPSL) [RFC2622] allow network operators to publish routing policies, including source-based policies for BGP advertisements.

Differences from SSB:

* Routing Paradigm: IRR/RPSL focus entirely on destination routing; they lack data structures to map allowed source prefixes to destination space.
* Cryptographic security: IRR/RPSL lack strong authentication; SSB uses RPKI signatures.
* Data plane enforcement: IRR/RPSL are informational and revolve around control plane; SSB enables automated data plane filter installation.
* Adoption: IRR data quality and authentication are inconsistent; SSB builds on the more rigorous RPKI framework.

# Security Considerations

## RPKI Security Model

SSB inherits the security properties of RPKI:

* Trust anchor: The five Regional Internet Registries (RIRs) operate RPKI trust anchors.
* Certificate hierarchy: Resource certificates bind IP prefixes and AS numbers to public keys.
* Signed objects: SPAs are signed using the prefix holder's certificate, ensuring authenticity and integrity.

Threats and mitigations:

* Compromise of RPKI trust anchor: Would allow forging SPAs for any prefix. Mitigation: RIRs follow rigorous operational security practices; multiple trust anchors provide some redundancy.
* Compromise of resource certificate: Would allow an attacker to forge SPAs for the covered prefixes. Mitigation: Certificate holders should protect private keys using Hardware Security Modules (HSMs) and follow key management best practices.
* Replay attacks: An attacker could replay an old, expired SPA. Mitigation: SPAs include validity periods and are checked against the current time; RPKI validators distribute only currently valid SPAs.

SSB assumes the integrity of the RPKI trust hierarchy for authorization, while making no assumptions about the trustworthiness of the global BGP control plane beyond reachability propagation.

## Source Address Validation

SSB enforces source-based filtering but does not, by itself, validate that packets are actually originated from the claimed source prefix (i.e., it does not prevent source address spoofing).

Complementary mechanisms:

* Source Address Validation (SAV): Techniques such as BCP 38 [RFC2827] (ingress filtering) and uRPF (Unicast Reverse Path Forwarding) [RFC3704] prevent spoofing by verifying that packets arrive on interfaces consistent with the source address.
* RPKI-based SAV: Proposals exist to use RPKI to enhance SAV (e.g., by distributing prefix-to-AS mappings).

Operators deploying SSB are strongly encouraged to also deploy SAV mechanisms to ensure that source addresses cannot be spoofed.

## Denial of Service Vectors

Potential DoS attacks against SSB infrastructure:

* SPA repository flooding: An attacker could publish large numbers of SPAs to overwhelm validators and routers. Mitigation: RPKI repositories have size limits and rate-limiting; routers can selectively fetch SPAs for prefixes of interest.
* SPA validation overhead: An attacker could advertise many prefixes with SOURCE_SELECTIVE attributes to force RPKI Validators to process many SPAs. Mitigation: RPKI Validators can cache validated SPAs and rate-limit validation requests.
* Data plane filter exhaustion: An attacker could attempt to exhaust router memory by advertising many prefixes with large source prefix lists. Mitigation: Routers can limit the number of SPA filters installed and prioritize enforcement for critical prefixes.

## Operational Security

Best practices for operators deploying SSB:

* Protect RPKI private keys: Use HSMs and restrict access to key material.
* Validate SPA signatures: Ensure RPKI Validators verify cryptographic signatures before sending the SPA payload to routers.
* Monitor SPA publication: Detect unauthorized or unexpected SPAs for your prefixes.
* Test SPA configurations: Verify that SPAs correctly authorize intended sources and do not inadvertently block legitimate traffic.
* Coordinate with partners: When deploying SSB for B2B connectivity, coordinate with partners to ensure their source prefixes are correctly authorized.

## BGP Control Plane Manipulation

Like standard path attributes, SOURCE_SELECTIVE signaling is susceptible to manipulation, such as removal or SA-ID inflation, by transit routers along the path. Because this vulnerability is inherent to BGP, mitigation relies on established internet peering reputations, reinforced by public ISP looking glass portals that allow external operators to openly audit and detect Path Attribute modifications.

# IANA Considerations

This document makes no requests of IANA.

# Acknowledgments

The author would like to thank Ritesh Mukherjee (Nokia) and individual reviewers from the IETF community for their valuable feedback and contributions during the development of this document.

The design of Source-Selective BGP (SSB) builds on decades of work in BGP, RPKI, and secure routing, and the author gratefully acknowledges the contributions of the IETF IDR, SIDROPS, and GROW working groups.
