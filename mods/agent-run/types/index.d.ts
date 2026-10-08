export type AgentType = { name: string; description: string }
export type Run = { agentId: string; type: string; task: string; status: 'running' | 'done' | 'failed' }

declare module 'claude-code' {
  interface PluginState {
    'agent-run': {
      types: AgentType[]
      picked: string | null
      runs: Run[]
    }
  }
}
