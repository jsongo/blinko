#!/usr/bin/env bun
/**
 * Script to move "#flomo " prefix from the beginning of notes to the end
 * Usage: bun scripts/fix-flomo-prefix.ts
 */

import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

async function fixFlomoPrefix() {
  console.log('Starting to fix flomo prefix in notes...')

  try {
    // Find all notes that start with "#flomo "
    const notesWithFlomoPrefix = await prisma.notes.findMany({
      where: {
        content: {
          startsWith: '#flomo '
        },
        isRecycle: false
      },
      select: {
        id: true,
        content: true
      }
    })

    console.log(`Found ${notesWithFlomoPrefix.length} notes with #flomo prefix`)

    if (notesWithFlomoPrefix.length === 0) {
      console.log('No notes to process.')
      return
    }

    let successCount = 0
    let errorCount = 0

    for (const note of notesWithFlomoPrefix) {
      try {
        // Remove "#flomo " from the beginning (7 characters including space)
        const contentWithoutPrefix = note.content.substring(7)

        // Add "#flomo " to the end with a newline
        const newContent = `${contentWithoutPrefix}\n#flomo `

        await prisma.notes.update({
          where: { id: note.id },
          data: { content: newContent }
        })

        successCount++
        console.log(`✓ Processed note ${note.id}: ${note.content.substring(0, 50)}...`)
      } catch (error) {
        errorCount++
        console.error(`✗ Failed to process note ${note.id}:`, error)
      }
    }

    console.log('\n=== Summary ===')
    console.log(`Total found: ${notesWithFlomoPrefix.length}`)
    console.log(`Successfully processed: ${successCount}`)
    console.log(`Failed: ${errorCount}`)
  } catch (error) {
    console.error('Error:', error)
  } finally {
    await prisma.$disconnect()
  }
}

// Run the script
fixFlomoPrefix()
