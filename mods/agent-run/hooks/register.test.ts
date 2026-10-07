import { expect, test } from 'claude-code/testing'

import { messages, pickRun } from './register'

const spawned: any[] = []

function engine(on: any, agentId: string | null = 'a1') {
  spawned.length = 0
  on('agent.spawn', (_$: unknown, e: unknown) => {
    spawned.push(e)
    return agentId ? { model: 'test', agentId } : { deny: '정책상 막힘' }
  })
  on('agent.offer', () => ({ isOffered: true }))
  on('ui.toast', () => undefined)
}

const RUN = { agentId: 'a1', type: 'developer', task: '일', status: 'running' } as const

// ── 정상 ──
test('정상: /agent-run 이름 작업 → 그 에이전트를 그 작업으로 띄운다', async ($, on) => {
  engine(on)
  await $.command.run({ command: 'agent-run', args: 'developer 테스트를 써라' } as any)
  expect(spawned).toHaveLength(1)
  expect(spawned[0]).toMatchObject({ subagent_type: 'developer', prompt: '테스트를 써라' })
})

test('정상: 끝난 실행은 사람용 알림과 모델용 전문 두 행이 된다', () => {
  const m = messages(RUN, 'answer', '결과 본문')
  expect(m.ok).toBe(true)
  expect(m.notice).toContain('[agent-run] developer — 일')
  expect(m.full).toContain('결과 본문')
})

test('정상: agent.offer 로 소개된 타입만 받는다', async ($, on) => {
  engine(on)
  await $.agent.offer({ agent: 'developer', description: '개발자', source: 'user', provider: { plugin: 'engine', tier: 'core' } } as any)
  const out = await $.command.run({ command: 'agent-run', args: 'nobody 일' } as any)
  expect(out.text).toContain('모르는 에이전트')
  expect(spawned).toHaveLength(0)
})

// ── 실패 ──
test('실패: spawn 이 거절되면 사유를 알린다', async ($, on) => {
  engine(on, null)
  const out = await $.command.run({ command: 'agent-run', args: 'developer 일' } as any)
  expect(out.text).toContain('정책상 막힘')
})

test('실패: 중단된 에이전트는 실패로 알린다', () => {
  const m = messages(RUN, 'aborted', '')
  expect(m.ok).toBe(false)
  expect(m.notice).toContain('끝나지 못했다 (aborted)')
})

// ── 경계값 ──
test('경계: 메인 루프·남이 띄운 에이전트·이미 끝난 실행은 고르지 않는다', () => {
  expect(pickRun([RUN], undefined)).toBeUndefined()
  expect(pickRun([RUN], 'someone-else')).toBeUndefined()
  expect(pickRun([{ ...RUN, status: 'done' }], 'a1')).toBeUndefined()
  expect(pickRun([RUN], 'a1')).toEqual(RUN)
})

test('경계: 긴 결과는 알림에서 1500자로 자르고 전문은 그대로 둔다', () => {
  const m = messages(RUN, 'answer', 'x'.repeat(3000))
  expect(m.notice).toContain('1500자 생략')
  expect(m.full).toContain('x'.repeat(3000))
  expect(messages(RUN, 'answer', 'x'.repeat(1500)).notice).not.toContain('생략')
})

test('경계: 작업 없이 이름만 주면 띄우지 않고 패널로 보낸다', async ($, on) => {
  engine(on)
  on('ui.open', () => ({ value: { isPlaced: true } }))
  const out = await $.command.run({ command: 'agent-run', args: 'developer' } as any)
  expect(spawned).toHaveLength(0)
  expect(out.text).toContain('패널에서 작업을 입력한다')
})
