import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { Layout } from './components/Layout'
import { OverviewPage } from './pages/Overview'
import { SourcesPage } from './pages/Sources'
import { ChannelsPage } from './pages/Channels'
import { TemplatesPage } from './pages/Templates'
import { RoutingPage } from './pages/Routing'
import { RecipientsPage } from './pages/Recipients'
import { IntegrationsPage } from './pages/Integrations'
import { LogsPage } from './pages/Logs'
import { PlaygroundPage } from './pages/Playground'

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<OverviewPage />} />
          <Route path="sources" element={<SourcesPage />} />
          <Route path="channels" element={<ChannelsPage />} />
          <Route path="templates" element={<TemplatesPage />} />
          <Route path="routing" element={<RoutingPage />} />
          <Route path="recipients" element={<RecipientsPage />} />
          <Route path="integrations" element={<IntegrationsPage />} />
          <Route path="logs" element={<LogsPage />} />
          <Route path="playground" element={<PlaygroundPage />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}
