## Agent descriptions

You should put your agent description files in this directory.
An agent description file is the agent hostname with an extension of .agent
e.g. `hostile-17.agent` would create an agent with a hostname of `hostile-17`.

Example agent description file:

```
AGENT_ETHERNET=b8:27:eb:81:1a:52
AGENT_IP=192.168.64.65
AGENT_RANCHER_PART_UUID=d5f9e6c2-493c-48da-baf2-0c63dd7a36b1
AGENT_SWAP_PART_UUID=e5f9e6c2-493c-48da-baf2-0c63dd7a36b2
AGENT_PXE_ID=c6811a52
AGENT_K3S_ARGS="--node-label 'smarter-device-manager=enabled'"
```
