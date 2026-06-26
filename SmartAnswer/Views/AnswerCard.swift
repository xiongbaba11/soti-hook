import SwiftUI

struct AnswerCard: View {
    let question: Question
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Source badge
            HStack {
                Image(systemName: question.source == "local" ? "books.vertical.fill" : "brain")
                    .font(.system(size: 12))
                Text(question.source == "local" ? "本地题库" : question.source)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(question.source == "local" ? DuoColors.green : DuoColors.blue)
            )
            
            // Question text
            Text(question.question)
                .font(.system(size: 15))
                .lineLimit(3)
            
            // Answer
            Text(question.answer)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(DuoColors.green)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(DuoColors.white)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}
