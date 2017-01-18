# SFC OVS rules

## Setup

## Rules

In the following steps are the OpenFlow rules which are needed for the SFC

### Node 1 (VXLAN 192.168.0.)

Client VM was running on this node:

```bash
cookie=0x1110070001170254, table=1, priority=40000,
  nsi=254,nsp=117,reg0=0x1,in_port=0 # port 0 = ovs-system (internal)
  actions=
    pop_nsh, # Decapsulation
    goto_table:21

cookie=0x1110010001170255, table=11,
  tcp,reg0=0x1,tp_dst=80 # Classifier match
  actions=
    move:NXM_NX_TUN_ID[0..31]->NXM_NX_NSH_C2[], # Move Tunnel ID in Context Header 2 0x3ed -> 1005 # defined via --provider:segmentation_id 1005
    push_nsh, # Create NSH
      load:0x1->NXM_NX_NSH_MDTYPE[], # 1
      load:0x3->NXM_NX_NSH_NP[], # 3
      load:0xc0a80003->NXM_NX_NSH_C1[], # 192.168.0.3 -> Node with SF
      load:0x75->NXM_NX_NSP[0..23], # 117
      load:0xff->NXM_NX_NSI[], # 255
      load:0xc0a80003->NXM_NX_TUN_IPV4_DST[], # 192.168.0.3 -> Node with SF
      load:0x75->NXM_NX_TUN_ID[0..31], # 117
    output:6 # VXGPE Port

cookie=0x1110010001170255, table=11,
  tcp,reg0=0x1,tp_dst=22 # Classifier match
  actions=
    move:NXM_NX_TUN_ID[0..31]->NXM_NX_NSH_C2[], # Move Tunnel ID in Context Header 2 (1005)
    push_nsh,
      load:0x1->NXM_NX_NSH_MDTYPE[], # 1
      load:0x3->NXM_NX_NSH_NP[], # 3
      load:0xc0a80003->NXM_NX_NSH_C1[], # 192.168.0.3 -> Node with SF
      load:0x75->NXM_NX_NSP[0..23], # 117
      load:0xff->NXM_NX_NSI[], # 255
      load:0xc0a80003->NXM_NX_TUN_IPV4_DST[], # 192.168.0.3 -> Node with SF
      load:0x75->NXM_NX_TUN_ID[0..31], # 117
    output:6 # VXGPE Port

cookie=0x1110060001170254, table=11,
  nsi=254,nsp=117,in_port=6
  actions=
    load:0x1->NXM_NX_REG0[], # Port is local
    move:NXM_NX_NSH_C2[]->NXM_NX_TUN_ID[0..31], # Move Context Header 2 into Tunnel ID (for decapsulation) (1005)
    resubmit(0,1) # resubmit in port 0 table 1 -> port 0 = ovs-system (internal)
```

### Node 2 (VXLAN 192.168.0.3)

On this node the Service Function (SF) and the Server were running:

```bash
cookie=0x14, table=0,
  priority=250,nsp=117 # If SFC with SPI 117
  actions=
    goto_table:152

cookie=0x1110070001170254, table=1, priority=40000,
  nsi=254,nsp=117,reg0=0x1,in_port=7 # in port SF VM
  actions=
    pop_nsh, # Decapsulation
    goto_table:21

cookie=0x1110010001170255, table=11,
  tcp,reg0=0x1,tp_dst=80 # Classifier match
  actions=
    move:NXM_NX_TUN_ID[0..31]->NXM_NX_NSH_C2[], # Move Tunnel ID in Context Header 2 (1005)
    push_nsh,
      load:0x1->NXM_NX_NSH_MDTYPE[], # 1
      load:0x3->NXM_NX_NSH_NP[], # Next Protocol 0x3 -> Ethernet
      load:0xc0a80003->NXM_NX_NSH_C1[], # 192.168.0.3
      load:0x75->NXM_NX_NSP[0..23], # 117
      load:0xff->NXM_NX_NSI[], # 255
      load:0xb000005->NXM_NX_TUN_IPV4_DST[], # 11.0.0.5
      load:0x75->NXM_NX_TUN_ID[0..31], # 117
  resubmit(,0) # resubmit in same port table 0

cookie=0x1110010001170255, table=11,
  tcp,reg0=0x1,tp_dst=22 # Classifier match
  actions=
    move:NXM_NX_TUN_ID[0..31]->NXM_NX_NSH_C2[], # Move Tunnel ID in Context Header 2 (1005)
    push_nsh,
      load:0x1->NXM_NX_NSH_MDTYPE[], # 1
      load:0x3->NXM_NX_NSH_NP[], # Next Protocol 0x3 -> Ethernet
      load:0xc0a80003->NXM_NX_NSH_C1[], # 192.168.0.3
      load:0x75->NXM_NX_NSP[0..23],  # 117
      load:0xff->NXM_NX_NSI[],  # 255
      load:0xb000005->NXM_NX_TUN_IPV4_DST[], # 11.0.0.5
      load:0x75->NXM_NX_TUN_ID[0..31], # 117
    resubmit(,0) # resubmit in same port table 0

cookie=0x1110060001170254, table=11,
  nsi=254,nsp=117,in_port=8 # port 8 = vxgpe
  actions=
    load:0x1->NXM_NX_REG0[], # local reg0=0
    move:NXM_NX_NSH_C2[]->NXM_NX_TUN_ID[0..31], # Move Context Header 2 into Tunnel ID (for decapsulation)
    resubmit(7,1)  # resubmit in port 7 table 1

cookie=0x14, table=150, actions=goto_table:151
cookie=0x14, table=151, actions=goto_table:152

cookie=0x14, table=152, priority=550,
  nsi=255,nsp=117
  actions=
    load:0xb000005->NXM_NX_TUN_IPV4_DST[], # 11.0.0.5
    goto_table:158

cookie=0x14, table=152, priority=5 actions=goto_table:158

cookie=0xba5eba1100000102, table=158, priority=660,
  nsi=254,nsp=117,nshc1=0 # NSH Context Header 1 contains "0"
  actions=IN_PORT

cookie=0xba5eba1100000104, table=158, priority=660,
  nsi=254,nsp=117,nshc1=3232235523 # NSH Context Header 1 contains "192.168.0.3"
  actions=
    move:NXM_NX_NSH_MDTYPE[]->NXM_NX_NSH_MDTYPE[], # Copy NSH MD Type 1
    move:NXM_NX_NSH_NP[]->NXM_NX_NSH_NP[], # Copy Next Protocol (0x3 Ethernet)
    move:NXM_NX_NSI[]->NXM_NX_NSI[], # Copy Service Path Index (254)
    move:NXM_NX_NSP[0..23]->NXM_NX_NSP[0..23], #  Copy Service Path Identifier (117)
    move:NXM_NX_NSH_C1[]->NXM_NX_TUN_IPV4_DST[], # Move NSH Context Header 1 into Tunnel IPv4 dst (192.168.0.3)
    move:NXM_NX_NSH_C2[]->NXM_NX_TUN_ID[0..31], # Move NSH Context Header 2 into Tunnel ID (1005)
    load:0x4->NXM_NX_TUN_GPE_NP[], # Next Protocol NSH
  resubmit(,11) # resubmit on the same port table 11

cookie=0xba5eba1100000101, table=158, priority=655,
  nsi=255,nsp=117,in_port=8
  actions=
    move:NXM_NX_NSH_MDTYPE[]->NXM_NX_NSH_MDTYPE[], # Copy NSH MD Type 1 (0x1)
    move:NXM_NX_NSH_NP[]->NXM_NX_NSH_NP[], # Copy Next Protocol (0x3 - Ethernet)
    move:NXM_NX_NSH_C1[]->NXM_NX_NSH_C1[], # Copy Context Header 1 (192.168.0.3)
    move:NXM_NX_NSH_C2[]->NXM_NX_NSH_C2[], # Copy Context Header 2 (1005)
    move:NXM_NX_TUN_ID[0..31]->NXM_NX_TUN_ID[0..31], # Move NSH Context Header 2 into Tunnel ID (1005)
    load:0x4->NXM_NX_TUN_GPE_NP[], # Next Protocol NSH
  IN_PORT # Output on Inport (8) -> vxgpe port

cookie=0xba5eba1100000101, table=158, priority=650,
  nsi=255,nsp=117
  actions=
    move:NXM_NX_NSH_MDTYPE[]->NXM_NX_NSH_MDTYPE[], # Copy NSH MD Type 1 (0x1)
    move:NXM_NX_NSH_NP[]->NXM_NX_NSH_NP[], # Copy Next Protocol (0x3 - Ethernet)
    move:NXM_NX_NSH_C1[]->NXM_NX_NSH_C1[], # Copy Context Header 1 (192.168.0.3)
    move:NXM_NX_NSH_C2[]->NXM_NX_NSH_C2[], # Copy Context Header 2 (1005)
    move:NXM_NX_TUN_ID[0..31]->NXM_NX_TUN_ID[0..31], # Move NSH Context Header 2 into Tunnel ID (1005)
    load:0x4->NXM_NX_TUN_GPE_NP[], # Next Protocol NSH
  output:8 # Output on port (8) -> vxgpe port

cookie=0xba5eba1100000103, table=158, priority=650,
  nsi=254,nsp=117 # Finished SFC
  actions=
    move:NXM_NX_NSH_MDTYPE[]->NXM_NX_NSH_MDTYPE[], # Copy NSH MD Type 1
    move:NXM_NX_NSH_NP[]->NXM_NX_NSH_NP[], # Copy Next Protocol (0x3 Ethernet)
    move:NXM_NX_NSI[]->NXM_NX_NSI[], # Copy Service Path Index (254)
    move:NXM_NX_NSP[0..23]->NXM_NX_NSP[0..23], # Copy Service Path Identifier (117)
    move:NXM_NX_NSH_C1[]->NXM_NX_TUN_IPV4_DST[], # Move NSH Context Header 1 into Tunnel IPv4 dst (?) must be != 192.168.0.3
    move:NXM_NX_NSH_C2[]->NXM_NX_TUN_ID[0..31],  # Move NSH Context Header 2 into Tunnel ID (1005)
    load:0x4->NXM_NX_TUN_GPE_NP[], # Next Protocol NSH
  IN_PORT  # Output on Inport (8) -> vxgpe port

cookie=0x14, table=158, priority=5
  actions=drop
```

## Sources

- <https://tools.ietf.org/html/draft-ietf-sfc-nsh-10>
- <https://tools.ietf.org/html/draft-ietf-nvo3-vxlan-gpe-03>
