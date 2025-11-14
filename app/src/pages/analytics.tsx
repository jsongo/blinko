import React, { useEffect } from 'react'
import { observer } from "mobx-react-lite"
import { RootStore } from "@/store/root"
import { AnalyticsStore } from "@/store/analyticsStore"
import { useTranslation } from "react-i18next"
import { HeatMap } from "@/components/BlinkoAnalytics/HeatMap"
import { StatsCards } from "@/components/BlinkoAnalytics/StatsCards"
import { TagDistributionChart } from "@/components/BlinkoAnalytics/TagDistributionChart"
import dayjs from "dayjs"
import { Dropdown, DropdownTrigger, DropdownMenu, DropdownItem, Button } from "@heroui/react"
import { Icon } from '@/components/Common/Iconify/icons'
import { ScrollArea } from '@/components/Common/ScrollArea'

const Analytics = observer(() => {
  const analyticsStore = RootStore.Get(AnalyticsStore)
  const { t } = useTranslation()
  const [selectedMonth, setSelectedMonth] = React.useState(dayjs().format("YYYY-MM"))
  analyticsStore.use()

  useEffect(() => {
    console.debug('[Analytics] useEffect triggered - selectedMonth:', selectedMonth)
    if (selectedMonth) {
      analyticsStore.setSelectedMonth(selectedMonth)
    } else {
      console.debug('[Analytics] selectedMonth is undefined, skipping API call')
    }
  }, [selectedMonth])

  const currentMonth = dayjs().format("YYYY-MM")
  const monthOptions = [
    { key: "all", label: t('all') || "All" },
    ...Array.from({ length: 12 }, (_, i) => {
      const month = dayjs().subtract(i, "month").format("YYYY-MM")
      return { key: month, label: month }
    })
  ]

  const data = analyticsStore.dailyNoteCount.value?.map(item => [
    item.date,
    item.count
  ] as [string, number]) ?? []

  const stats = analyticsStore.monthlyStats.value

  const handleDateClick = (date: string) => {
    if (!date) {
      console.debug('[Analytics] handleDateClick - date is undefined or empty, ignoring')
      return
    }
    // Use the exact date (YYYY-MM-DD) for day-level statistics
    console.debug('[Analytics] handleDateClick - clicked date:', date)
    if (dayjs(date).isValid()) {
      setSelectedMonth(date)
    } else {
      console.debug('[Analytics] handleDateClick - date is invalid:', date)
    }
  }

  return (
    <ScrollArea onBottom={() => { }} fixMobileTopBar className="px-6 space-y-2 md:p-6 md:space-y-6  mx-auto max-w-7xl" >
      <div className="w-72">
        <Dropdown>
          <DropdownTrigger>
            <Button
              variant="flat"
              className="w-[160px] justify-between bg-default-100 hover:bg-default-200"
              size="md"
              endContent={<Icon icon="mdi:chevron-down" className="h-4 w-4" />}
              startContent={<Icon icon="mdi:calendar" className="h-4 w-4" />}
            >
              {selectedMonth === "all" ? (t('all') || "All") : selectedMonth}
            </Button>
          </DropdownTrigger>
          <DropdownMenu
            aria-label="Select month"
            selectionMode="single"
            selectedKeys={[selectedMonth]}
            className="max-h-[400px]"
            onSelectionChange={(key) => {
              const value = Array.from(key)[0] as string
              console.debug('[Analytics] Dropdown onSelectionChange - key:', key, 'value:', value)
              if (value) {
                setSelectedMonth(value)
              } else {
                console.debug('[Analytics] Dropdown value is undefined, ignoring')
              }
            }}
          >
            {monthOptions.map((option) => (
              <DropdownItem
                key={option.key}
                className="data-[selected=true]:bg-primary-500/20"
              >
                {option.label}
              </DropdownItem>
            ))}
          </DropdownMenu>
        </Dropdown>
      </div>

      <StatsCards stats={stats ?? {}} />

      <HeatMap
        data={data}
        title={t('heatMapTitle')}
        description={t('heatMapDescription')}
        onDateClick={handleDateClick}
      />

      {
        stats?.tagStats && stats.tagStats.length > 0 && (
          <TagDistributionChart tagStats={stats.tagStats} />
        )
      }
    </ScrollArea >
  )
})

export default Analytics