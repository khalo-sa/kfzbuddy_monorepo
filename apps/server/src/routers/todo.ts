import z from 'zod';
import { db } from '../db';
import { publicProcedure, router } from '../lib/trpc';

export const todoRouter = router({
  getAll: publicProcedure.query(async () => {
    return await db.todo.findMany();
  }),

  create: publicProcedure
    .input(z.object({ text: z.string().min(1) }))
    .mutation(async ({ input }) => {
      return await db.todo.create({
        data: {
          text: input.text,
        },
      });
    }),

  toggle: publicProcedure
    .input(z.object({ id: z.number(), completed: z.boolean() }))
    .mutation(async ({ input }) => {
      return await db.todo.update({
        where: { id: input.id },
        data: { completed: input.completed },
      });
    }),

  delete: publicProcedure
    .input(z.object({ id: z.number() }))
    .mutation(async ({ input }) => {
      return await db.todo.delete({
        where: { id: input.id },
      });
    }),
});
