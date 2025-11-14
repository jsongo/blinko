const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function resetSequences() {
  try {
    console.log('Resetting database sequences...');
    
    await prisma.$executeRaw`SELECT setval('notes_id_seq', COALESCE((SELECT MAX(id) FROM "notes"), 0) + 1);`;
    console.log('✓ notes_id_seq reset');
    
    await prisma.$executeRaw`SELECT setval('tag_id_seq', COALESCE((SELECT MAX(id) FROM "tag"), 0) + 1);`;
    console.log('✓ tag_id_seq reset');
    
    await prisma.$executeRaw`SELECT setval('"tagsToNote_id_seq"', COALESCE((SELECT MAX(id) FROM "tagsToNote"), 0) + 1);`;
    console.log('✓ tagsToNote_id_seq reset');
    
    await prisma.$executeRaw`SELECT setval('attachments_id_seq', COALESCE((SELECT MAX(id) FROM "attachments"), 0) + 1);`;
    console.log('✓ attachments_id_seq reset');
    
    // Show current sequence values
    const noteSeq = await prisma.$queryRaw`SELECT last_value FROM notes_id_seq;`;
    const tagSeq = await prisma.$queryRaw`SELECT last_value FROM tag_id_seq;`;
    const tagsToNoteSeq = await prisma.$queryRaw`SELECT last_value FROM "tagsToNote_id_seq";`;
    const attachmentsSeq = await prisma.$queryRaw`SELECT last_value FROM attachments_id_seq;`;
    
    console.log('\nCurrent sequence values:');
    console.log('notes_id_seq:', noteSeq[0].last_value);
    console.log('tag_id_seq:', tagSeq[0].last_value);
    console.log('tagsToNote_id_seq:', tagsToNoteSeq[0].last_value);
    console.log('attachments_id_seq:', attachmentsSeq[0].last_value);
    
    console.log('\n✓ All sequences reset successfully!');
  } catch (error) {
    console.error('Error resetting sequences:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

resetSequences();
