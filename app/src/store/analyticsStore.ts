import { makeAutoObservable } from "mobx"
import { Store } from './standard/base';
import { api } from "@/lib/trpc";
import { PromiseState } from "./standard/PromiseState";
import { useEffect } from "react";
import dayjs from "dayjs";

interface MonthlyStats {
  noteCount: number;
  totalWords: number;
  maxDailyWords: number;
  activeDays: number;
  tagStats?: {
    tagName: string;
    count: number;
  }[];
}

export class AnalyticsStore implements Store {
  sid = 'AnalyticsStore';
  selectedMonth: string = dayjs().format("YYYY-MM");

  constructor() {
    makeAutoObservable(this)
  }

  setSelectedMonth(month: string) {
    console.debug('[AnalyticsStore] setSelectedMonth called with:', month)
    if (!month) {
      console.debug('[AnalyticsStore] month is undefined or empty, skipping')
      return
    }
    this.selectedMonth = month;
    console.debug('[AnalyticsStore] selectedMonth updated to:', this.selectedMonth)
    this.dailyNoteCount.call();
    this.monthlyStats.call();
  }

  dailyNoteCount = new PromiseState({
    function: async () => {
      const data = await api.analytics.dailyNoteCount.mutate()
      return data
    }
  })

  monthlyStats = new PromiseState({
    function: async () => {
      console.debug('[AnalyticsStore] monthlyStats.function called - this.selectedMonth:', this.selectedMonth)
      const data = await api.analytics.monthlyStats.mutate({
        month: this.selectedMonth
      }) as MonthlyStats
      return data
    }
  })

  use() {
    useEffect(() => {
      this.dailyNoteCount.call()
      this.monthlyStats.call()
    }, [])
  }
}