// agent-run — 에이전트를 골라 작업을 맡긴다.
//
//   /agent-run                      패널을 연다. 에이전트를 고르고 작업을 입력한다
//   /agent-run <에이전트> <작업>      패널 없이 바로 맡긴다
//
// 에이전트 목록은 엔진이 모델에게 에이전트를 소개할 때(agent.offer) 모은다.
// 맡긴 에이전트가 끝나면(turn.complete) 결과를 두 번 붙인다.
//   - 사람이 보는 알림 행 (system) — 앞부분만
//   - 모델이 읽는 행 (user, 사람에게는 숨김) — 전문. 다음 질문부터 Claude 가 결과를 안다

import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { AgentType, Run } from '../types'

const PANE = 'agent-run'
const NOTICE_CHARS = 1500

const types = atom({ plugin: 'agent-run', key: 'types' } as const, [])
const picked = atom({ plugin: 'agent-run', key: 'picked' } as const, null)
const runs = atom({ plugin: 'agent-run', key: 'runs' } as const, [])

/** 이 turn.complete 가 우리가 맡긴 실행 중 에이전트의 것이면 그 실행을, 아니면 undefined. */
export function pickRun(list: readonly Run[], agentId: string | undefined): Run | undefined {
  return agentId ? list.find(r => r.agentId === agentId && r.status === 'running') : undefined
}

/** 끝난 실행을 사람용 알림(앞부분)과 모델용 전문 두 행으로 만든다. */
export function messages(run: Run, reason: string, answer: string): { ok: boolean; notice: string; full: string } {
  const ok = reason === 'answer'
  const head = `[agent-run] ${run.type} — ${run.task}`
  const body = ok ? answer : `끝나지 못했다 (${reason})`
  const cut = body.length > NOTICE_CHARS ? `${body.slice(0, NOTICE_CHARS)}\n… (${body.length - NOTICE_CHARS}자 생략)` : body
  return { ok, notice: `${head}\n${cut}`, full: `${head}\n결과 전문:\n${body}` }
}

/** 에이전트를 띄우고 실행 목록에 올린다. 거절되면 그 사유를 돌려준다. */
async function start($: any, type: string, task: string): Promise<string> {
  const result = await $.agent.spawn({
    subagentType: type,
    prompt: task,
    description: task.slice(0, 40),
  })
  if (result.deny || !result.agentId) {
    return `에이전트를 띄우지 못했다: ${result.deny ?? '사유 없음'}`
  }
  const run: Run = { agentId: result.agentId, type, task, status: 'running' }
  await update($, runs, list => [...list, run].slice(-20))
  $.ui.toast(`${type} 시작: ${task.slice(0, 40)}`)
  return `${type} 에게 맡겼다. 끝나면 결과를 대화에 붙인다.`
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'agent-run',
      description: '에이전트를 골라 작업을 맡긴다',
      argumentHint: '[에이전트] [작업]',
    })
    return next(e)
  })

  // 모델에게 소개되는 에이전트 타입을 모은다. 소개 여부는 건드리지 않는다.
  on('agent.offer', async ($, e, next) => {
    const answer = await next(e)
    if (answer.isOffered) {
      const one: AgentType = { name: e.agent, description: e.description }
      // 목록을 못 적어도 모델에게 소개되는 데는 지장이 없어야 한다
      await update($, types, list =>
        list.some(t => t.name === one.name)
          ? list.map(t => (t.name === one.name ? one : t))
          : [...list, one].sort((a, b) => a.name.localeCompare(b.name)),
      ).catch(() => undefined)
    }
    return answer
  })

  on('command.run', { command: 'agent-run' }, async ($, e) => {
    const args = e.args.trim()
    if (args) {
      const [type = '', ...rest] = args.split(/\s+/)
      const task = rest.join(' ')
      const known = await read($, types)
      if (known.length > 0 && !known.some(t => t.name === type)) {
        return { text: `모르는 에이전트: ${type}. /agent-run 으로 목록을 연다.` }
      }
      if (!task) {
        await update($, picked, () => type)
        await $.ui.open({ id: PANE, title: 'Agent run', focus: true, closeOnEscape: true })
        return { text: `${type} — 패널에서 작업을 입력한다.` }
      }
      return { text: await start($, type, task) }
    }
    await update($, picked, () => null)
    await $.ui.open({ id: PANE, title: 'Agent run', focus: true, closeOnEscape: true })
    return { text: '에이전트 선택 패널을 열었다.' }
  })

  // 맡긴 에이전트가 끝나면 결과를 붙인다.
  on('turn.complete', async ($, e, next) => {
    const answer = await next(e)
    const run = pickRun(await read($, runs), e.agentId)
    if (!run) {
      return answer
    }
    const { ok, notice, full } = messages(run, e.reason, e.answer)
    await update($, runs, list =>
      list.map(r => (r.agentId === run.agentId ? { ...r, status: ok ? 'done' : 'failed' } : r)),
    )
    await $.session.append({ message: { type: 'system', content: [{ type: 'text', text: notice }] } })
    await $.session.append({ message: { type: 'user', content: [{ type: 'text', text: full }] } })
    $.ui.toast(`${run.type} ${ok ? '완료' : '실패'}`)
    return answer
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    if (e.surface === 'mobile') {
      // 모바일에는 Select·Input 이 없다
      const { Box, Text } = $.ui.resolve(e)
      return (
        <Box paddingX={1}>
          <Text>모바일에서는 패널을 쓸 수 없다. /agent-run 이름 작업 으로 맡긴다.</Text>
        </Box>
      )
    }
    const { Box, Text, Select, Input, Button } = $.ui.resolve(e)
    const list = await read($, types)
    const type = await read($, picked)
    const recent = (await read($, runs)).slice(-5).reverse()
    const close = () => void $.ui.close({ id: PANE })

    const history = recent.length > 0 && (
      <Box key="history" flexDirection="column" marginTop={1}>
        <Text dimColor>최근 맡긴 일</Text>
        {recent.map(r => (
          <Text key={r.agentId} dimColor={r.status !== 'running'} wrap="truncate-end">
            {r.status === 'running' ? '⏳' : r.status === 'done' ? '✓' : '✗'} {r.type} — {r.task}
          </Text>
        ))}
      </Box>
    )

    if (type === null) {
      return (
        <Box flexDirection="column" paddingX={1}>
          <Text bold>어느 에이전트에게 맡길까</Text>
          {list.length === 0 ? (
            <Text dimColor>아직 목록이 없다. 다음 응답이 끝나면 채워진다. /agent-run 이름 작업 으로 바로 맡길 수도 있다.</Text>
          ) : (
            <Select
              key="type"
              autoFocus
              options={list.map(t => ({ value: t.name, label: `${t.name} — ${t.description.slice(0, 60)}` }))}
              onSelect={(value: string) => void update($, picked, () => value)}
            />
          )}
          {history}
          <Button key="close" label="닫기" hotkey="q" onPress={close} />
        </Box>
      )
    }

    return (
      <Box flexDirection="column" paddingX={1}>
        <Text bold>{type} 에게 맡길 작업</Text>
        <Input
          key="task"
          autoFocus
          placeholder="무엇을 할지 적고 Enter"
          submitLabel="맡기기"
          onSubmit={(task: string) => {
            if (!task.trim()) return
            void start($, type, task.trim()).then(text => {
              if (!text.endsWith('붙인다.')) $.ui.toast(text)
            })
            close()
          }}
        />
        <Box key="buttons" gap={2} marginTop={1}>
          <Button key="back" label="← 다른 에이전트" hotkey="b" onPress={() => void update($, picked, () => null)} />
          <Button key="close" label="닫기" hotkey="q" onPress={close} />
        </Box>
        {history}
      </Box>
    )
  })
}
