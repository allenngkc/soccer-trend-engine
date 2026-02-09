import { PrismaClient } from '@prisma/client';

// Singleton Prisma Client instance
export const prisma = new PrismaClient();

// Re-export all Prisma types for use in other packages
export * from '@prisma/client';
